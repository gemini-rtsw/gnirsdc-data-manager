#!/usr/bin/env python

"""GNIRS Data Manager

Usage:
    gnirs_datamanager batch [-d] [-k] [-o <output_dir>] [-r]
    gnirs_datamanager daemon [-d] [-k] [-o <output_dir>] [-r]
    gnirs_datamanager (-h | --help)

Options:
    -h --help        This help message.
    -k               Keep raw files after processing
    -o <output_dir>  Output directory for the recovered files. It can be arbitrary.
                     By default it's the usual "fits" directory.
    -d               Debugging output. More verbose.
    -r               Include raw data in fits

Notes:
    The usual behavior for the data manager is to take raw files from the "new"
    directory (only those with an associated header file), and then try to
    process them.  To do this, the raw files are first moved to the "processing"
    directory.

    A successfully processed file will then appear in FITS format under the
    "fits" directory, and the raw files are removed, unless "-k" has been passed,
    in which case the files are moved to "processed_raw", where they'll wait to
    be removed by hand.

    If the processing triggers errors, the raw files are moved to the "error"
    directory and left for user inspection.

    In batch mode data manager runs only once, processing all existing files
    under "new" and then finishing. This mode is more useful for testing, or
    for mass recovery of (previously broken) raw data.

    In "daemon" mode, which should be the one used for regular operation, the
    manager waits in an infinite loop for new raw data to appear under "new",
    and process it as soon as available.

    Files that end up in "error" can be processed again (e.g., after fixing any
    problem) by just moving them to "new". But note that this is best done in
    batch mode, as otherwise one needs to guarantee that the raw image is moved
    first, then the header (to emulate the expected behavior).
"""

import json
import os
import shutil
#from logging import getLogger, Formatter, StreamHandler, INFO, DEBUG, FileHandler
from operator import attrgetter
import re
from pathlib import Path

from docopt import docopt
from astropy.io import fits
import numpy as np
from unscramble import Processor
import uuid
import traceback

from logging import getLogger

import gnirsutil

from fits_header_definitions import define_hdu_list, generate_new_filepath


from astropy.time import Time

#from . import __version__
__version__=0.1

DEFAULT_DATADIR = '/home/readout_data'



class ProcessingError(RuntimeError):
    pass

class RawDataNotFoundError(RuntimeError):
    pass


'''
def setup_logging(level, log_file=None, name_on_message=False, fmt_string=None):
    """
    Common logging setup for all SysCo processes.

    :param level: Minimum logging level. Everything lower than this will
        be filtered out. Admits a string or an integer.
        See https://docs.python.org/3.8/library/logging.html#logging-level
        for details.
    :param bool name_on_message: Whether to include the logger's name in the
        format string. Overriden if `fmt_string` has a value
    :param str fmt_string: Custom formatting string for our logs
    """
    root = getLogger()

    if fmt_string is None:
        if name_on_message:
            fmt_string = "%(asctime)s/%(name)s: %(message)s"
        else:
            fmt_string = "%(asctime)s: %(message)s"
    formatter = Formatter(fmt_string)
    handler = StreamHandler()
    handler.setFormatter(formatter)
    root.addHandler(handler)

    # FileHandler for file output
    if log_file:
        file_handler = FileHandler(log_file)
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)

    root.setLevel(level)
'''
    

class DataDir:
    def __init__(self, path):
        self.path = path
        self.logger = getLogger(f'DataDir{os.path.basename(path)}')
        try:
            os.makedirs(self.path, exist_ok=True)
            self.logger.info(f"Directory created or already exists: {self.path}")
        except Exception as e:
            self.logger.irdc_debug(f"Error creating directory {self.path}: {e}")


    def full_path(self, filename):
        return os.path.join(self.path, filename)

    def list_matched_files(self):
        "Lists of matching/not-matching files"
        
        files = os.listdir(self.path)

        # Using a regex to extract the base name before any frame or other numbering
        pattern = re.compile(r'^(.+?)(-\d+)?(\.frame\.\d+)?')

        raw_data = set()
        for x in files:
            match = pattern.match(x)
            if match:
                if x.endswith('.raw'):
                    raw_data.add(match.group(1))
                elif '.frame.' in x:
                    raw_data.add(match.group(1))

        paired = []
        unpaired = []

        for header in [x for x in files if x.endswith('.header')]:
            base_filename = os.path.splitext(header)[0]
            if base_filename not in raw_data:
                unpaired.append(header)
            else:
                raw_data.remove(base_filename)
                paired.append(base_filename)

        # Any leftover data files in raw_data have no matching header
        # but we don't touch them. Maybe there's something with a
        # header pending to be written
        for pending in raw_data:
            self.logger.info(f"Pending file {pending}")

        return paired, unpaired

class DataMover:
    def __init__(self, base_path, output_dir=None):
        self.base_path = base_path
        self.output_dir = output_dir
        self.logger = getLogger('DataMover')

    @property
    def new(self):
        return DataDir(os.path.join(self.base_path, 'new'))

    @property
    def error(self):
        return DataDir(os.path.join(self.base_path, 'error'))

    @property
    def proc_raw(self):
        return DataDir(os.path.join(self.base_path, 'processed_raw'))

    @property
    def processing(self):
        return DataDir(os.path.join(self.base_path, 'processing'))

    @property
    def output(self):
        if self.output_dir:
            return DataDir(self.output_dir)
        else:
            return DataDir(os.path.join(self.base_path, 'fits'))

    def move(self, move_from, move_to, fname, error_allowed=True):
        """
        Move a bunch of files between two directories

        `files` is a sequence of *base names*. So, if `files == ['foo']`,
        then two files will be moved: `foo.header` and `foo.raw`
        """
        try:
            src_path = move_from.full_path(fname)
            dst_path = Path(move_to.path) / Path(fname).name  # Ensures the file name is appended to the destination directory

            if dst_path.exists():  # Check if the destination file exists
                os.remove(dst_path)  # If it exists, remove it first

            shutil.move(src_path, dst_path)  # Now move the file
            self.logger.debug(f"Moved {src_path} -> {dst_path}")
        except (FileNotFoundError, FileExistsError) as e:
            if not error_allowed:
                raise e
            else:
                self.logger.irdc_debug(f"Failed to move {src_path} to {dst_path}: {e}")

    def delete_group(self, delete_from, prefix, error_allowed=True):
        """
        Delete a group of files within a directory that start with a given prefix
        """
        try:
            # Loop through files that start with the given prefix
            for fname in (x for x in os.listdir(delete_from.path) if x.startswith(f'{prefix}')):
                file_path = delete_from.full_path(fname)  # Construct the full path for each file
                if os.path.exists(file_path):  # Check if the file exists
                    os.remove(file_path)  # Delete the file
                    self.logger.debug(f"Deleted file: {file_path}")
                else:
                    raise FileNotFoundError(f"No such file: {file_path}")
        except Exception as e:
            if not error_allowed:
                raise e
            else:
                self.logger.irdc_debug(f"Failed to delete files from {delete_from.path}: {e}")


    def move_group(self, move_from, move_to, prefix):
        for full_name in (x for x in os.listdir(move_from.path) if x.startswith(f'{prefix}')):
            self.move(move_from, move_to, full_name)


def process_image(data, lnrs, ndavgs):
    if ndavgs == 1:
        processor = Processor(shift_delta=-8, full_frame=True)
        raw_reshaped = data.reshape((lnrs * 2, 512, 2048))
        reshaped = raw_reshaped.astype(np.float32)

        subtracted = reshaped[lnrs:] - reshaped[:lnrs]

        # Flip the image horizontally after unscrambling
        return np.flip(processor.unscramble(subtracted.mean(axis=0)))

    else:
        processor = Processor(shift_delta=0, full_frame=True)
        raw_reshaped = data.reshape((lnrs * 2, 512, 2048 * ndavgs))
        reshaped = raw_reshaped.astype(np.float32)
        averaged_samples = processor.ads_average(reshaped, ads_per_fowler=ndavgs)

        subtracted = averaged_samples[lnrs:] - averaged_samples[:lnrs]

        # Flip the image horizontally after unscrambling
        return np.flip(processor.unscramble(subtracted.mean(axis=0)))
    

def save_processed_image(data, lrns, ndavgs, exptime, hdulist, ext_header, include_eng):
    extname = 'ENG' if include_eng else 'SCI'
    ext_header['EXTNAME'] = extname

    if ndavgs == 1:
        processor = Processor(shift_delta=-8, full_frame=True)
        raw_reshaped = data.reshape((lrns * 2, 512, 2048))
        reshaped = raw_reshaped.astype(np.float32)
        subtracted = reshaped[lrns:] - reshaped[:lrns]

        # Flip the processed data horizontally after unscrambling
        primary_data = np.flip(processor.unscramble(subtracted.mean(axis=0)))
        hdulist.append(fits.ImageHDU(data=primary_data, header=ext_header))

        if include_eng == True:
            for fs_n in range(lrns * 2):
                is_signal = fs_n >= lrns
                read_type = 'S' if is_signal else 'R'
                index = fs_n - lrns if is_signal else fs_n
        
                ext_header['EXTNAME'] = f'{read_type}{index+1:02}'
                # Flip each engineering frame horizontally
                eng_data = np.flip(processor.unscramble(raw_reshaped[fs_n]))
                hdulist.append(fits.ImageHDU(eng_data, ext_header))

    else:
        processor = Processor(shift_delta=0, full_frame=True)
        raw_reshaped = data.reshape((lrns * 2, 512, 2048 * ndavgs))
        reshaped = raw_reshaped.astype(np.float32)
        averaged_samples = processor.ads_average(reshaped, ads_per_fowler=ndavgs)

        subtracted = averaged_samples[lrns:] - averaged_samples[:lrns]

        # Flip the processed data horizontally after unscrambling
        primary_data = np.flip(processor.unscramble(subtracted.mean(axis=0)))
        hdulist.append(fits.ImageHDU(data=primary_data, header=ext_header))

        if include_eng == True:
            # Separate the samples
            basic_cols = np.arange(32, dtype=int)
            offsets = (np.arange(64) * (32 * ndavgs))[:,None]
            cols_in_ads = (basic_cols + offsets).ravel()

            for fs_n in range(lrns * 2):  # This covers both reference and signal reads
                is_signal = fs_n >= lrns
                read_type = 'S' if is_signal else 'R'
                index = fs_n - lrns if is_signal else fs_n
            
                for fs_n, ads in enumerate([raw_reshaped[fs_n][:,cols_in_ads + (32 * sample)] for sample in range(ndavgs)]):
                    ext_header['EXTNAME'] = f'{read_type}{index+1:02}'
                    # Flip each engineering frame horizontally
                    eng_data = np.flip(processor.unscramble(ads))
                    hdulist.append(fits.ImageHDU(eng_data, ext_header))

class TimingMeasurement:
    def __init__(self, name, value):
        series, _, num = name.partition('_')
        self.ident = (series, int(num))
        self.value = float(value)



def extract_timing(samples_header, ext_header):
    for key, value in samples_header.items():
        # Format the values as decimal numbers
        formatted_value = f'{value:.6f}'
        ext_header[key] = formatted_value


def create_hdulist(header, raw_path, dc_commit = None, lib_commit = None): 
    raw_name = os.path.basename(raw_path)


    hdulist, ext_header, lnrs, ndavgs, raw_cols, raw_rows, coadds, exptime, p_mode, fname = define_hdu_list(header, dc_commit, lib_commit)


    # Append timing_header to ext_header
    if 'TIME_SAMPLES' in header:
        extract_timing(header['TIME_SAMPLES'], ext_header)

    total_frames = lnrs * 2
    frame_rows = raw_rows // total_frames
    raw_data = np.empty((raw_rows * raw_cols,), dtype=np.uint16)
    loading = raw_data.reshape((total_frames, frame_rows * raw_cols))
    coadd_data = np.empty((1024, 1024), dtype=np.float32)  # Initialize the array to store coadded data


    try: 
        if (coadds > 1):
            for coadd in range(coadds):
                for n in range(total_frames):
                    loading[n,:] = np.fromfile(f'{raw_path}-{coadd}.frame.{n}', dtype=np.uint16)

                coadd_data += process_image(raw_data.reshape((raw_rows, raw_cols)), lnrs, ndavgs)

            hdulist.append(fits.ImageHDU(coadd_data, header = ext_header))
        else:
            for n in range(total_frames):
                loading[n,:] = np.fromfile(f'{raw_path}-0.frame.{n}', dtype=np.uint16)
    except:
        raise RawDataNotFoundError(f"Raw Data Not Found {fname}: missing data, probably an aborted exposure")

    save_processed_image(raw_data.reshape((raw_rows, raw_cols)), lnrs, ndavgs, exptime, hdulist, ext_header, p_mode == 'SEP')

    # Print all headers in the HDU list to verify
#    for i, hdu in enumerate(hdulist):
#        print(f"Header of HDU {i}:")
#        print(repr(hdu.header))
#        print()

    return fname, hdulist

def decode_header(datadir, fname):
    # Extract the header information
    rpath = datadir.full_path(fname)
    rheader_file = f'{rpath}.header'
    try:
        header = json.load(open(rheader_file))
    except json.decoder.JSONDecodeError:
        raise ProcessingError(f"Processing {fname}: corrupt header file")

    return rpath, header

class DataProcessor:
    def __init__(self, mover, keep = False):
        self.datamov = mover
        self.keep = keep
        self.logger = getLogger('DataProcessor')


    

#    def process_file(self, fname, data_label = None, dc_commit = None, lib_commit = None):
    def process_file(self, fname, dc_commit=None, lib_commit=None):
        dm = self.datamov

        # Move files to processing
        try:
            dm.move_group(dm.new, dm.processing, fname)
        except Exception as e:
            self.logger.error(f"Error moving files to processing: {e}")
            raise ProcessingError(f"Failed to move files for {fname}")

        self.logger.debug(f"Processing {fname}")

        # Decode header
        try:
            rpath, header = decode_header(dm.processing, fname)
        except Exception as e:
            self.logger.error(f"Error decoding header for {fname}: {e}")
            dm.move_group(dm.processing, dm.error, fname)
            raise ProcessingError(f"Failed to decode header for {fname}")

        # Create HDU list
        try:
            fitsname, hdulist = create_hdulist(header, rpath, dc_commit, lib_commit)
        except Exception as e:
            self.logger.error(f"Error creating HDU list for {fname}: {e}")
            dm.move_group(dm.processing, dm.error, fname)
            raise ProcessingError(f"Failed to create HDU list for {fname}")

        # Write FITS file
        fits_path = dm.processing.full_path(fitsname)
        try:
            if os.access(fits_path, os.F_OK):
                fits_path = generate_new_filepath(fits_path)
                self.logger.debug(f"Changed name to: {fits_path}")
            
            self.logger.debug(f" -> writing to {fits_path}")
            hdulist.writeto(fits_path, overwrite=True)
        except Exception as e:
            self.logger.error(f"Error writing FITS file {fits_path}: {e}")
            dm.move_group(dm.processing, dm.error, fname)
            raise ProcessingError(f"Failed to write FITS file for {fname}")

        # Move processed file to output
        try:
            output_dir = dm.output.full_path('')
            self.logger.debug(f"Attempting to move processed file to output directory: {output_dir}")
            
            if not os.path.exists(output_dir):
                self.logger.error(f"Output directory does not exist: {output_dir}")
                os.makedirs(output_dir, exist_ok=True)
                self.logger.info(f"Created output directory: {output_dir}")

            source_file = dm.processing.full_path(fitsname)
            self.logger.debug(f"Source file: {source_file}")
            
            if not os.path.exists(source_file):
                self.logger.error(f"Source file does not exist: {source_file}")
                raise FileNotFoundError(f"Source file not found: {source_file}")

            dm.move(dm.processing, dm.output, fitsname, error_allowed=False)
            self.logger.info(f"Successfully moved processed file to output: {fitsname}")
        except Exception as e:
            self.logger.error(f"Error moving processed file to output: {e}")
            self.logger.error(f"Current working directory: {os.getcwd()}")
            self.logger.error(f"Files in processing directory: {os.listdir(dm.processing.full_path(''))}")
            raise ProcessingError(f"Failed to move processed file for {fname}")

        # Handle raw files
        if self.keep:
            dm.move_group(dm.processing, dm.proc_raw, fname)
        else:
            dm.delete_group(dm.processing, fname)

        self.logger.debug(f"Successfully processed {fname}")

def unscramble(data):
    return data

def batch_process(datamov, keep, raw):
    processor = DataProcessor(datamov, keep)
    for fname in datamov.new.list_matched_files()[0]:
        try:
            processor.process_file(fname)
        except Exception:
            ...

def daemon(datamov, keep):
    print("Daemon mode not functional yet")

def main():
    args = docopt(__doc__, version="GNIRS Engineering Data Manager v0.1")

    output_dir = args['-o'] or os.path.join(DEFAULT_DATADIR, 'fits')
    # keep = args['-k']
    keep = True

    #setup_logging(INFO if not args['-d'] and not args['--debug'] else DEBUG)

    dm = DataMover(DEFAULT_DATADIR, output_dir)

    raw = args['-r'] == True

    if args['batch']:
        batch_process(dm, keep, raw)
    elif args['daemon']:
        start_daemon(dm, keep)

if __name__ == '__main__':
    main()
