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
from logging import getLogger, Formatter, StreamHandler, INFO, DEBUG
from operator import attrgetter
import re
from pathlib import Path

from docopt import docopt
from astropy.io import fits
import numpy as np
from unscramble import Processor
#from . import __version__
__version__=0.1

DEFAULT_DATADIR = '/home/readout_data'

class ProcessingError(RuntimeError):
    pass

def setup_logging(level, name_on_message=False, fmt_string=None):
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
    root.setLevel(level)

class DataDir:
    def __init__(self, path):
        self.path = path
        self.logger = getLogger(f'DataDir{os.path.basename(path)}')
        try:
            os.makedirs(self.path, exist_ok=True)
            self.logger.info(f"Directory created or already exists: {self.path}")
        except Exception as e:
            self.logger.error(f"Error creating directory {self.path}: {e}")


    def full_path(self, filename):
        return os.path.join(self.path, filename)

    def list_matched_files(self):
        "Lists of matching/not-matching files"

        files = os.listdir(self.path)

        raw_data = set(os.path.splitext(x)[0] for x in files if x.endswith('.raw'))
        raw_data |= set(os.path.splitext(os.path.splitext(x)[0])[0] for x in files if ('.frame.' in x))
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
            # TODO: Log the pending...
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
                self.logger.error(f"Failed to move {src_path} to {dst_path}: {e}")

    def move_group(self, move_from, move_to, prefix):
        for full_name in (x for x in os.listdir(move_from.path) if x.startswith(f'{prefix}.')):
            self.move(move_from, move_to, full_name)

def save_processed_image(data, lrns, ndavgs, exptime, hdulist, include_eng):
    if ndavgs == 1:
        processor = Processor(shift_delta=-8, full_frame=True)
        raw_reshaped = data.reshape((lrns * 2, 512, 2048))
        reshaped = raw_reshaped.astype(np.float32)
        subtracted = reshaped[lrns:] - reshaped[:lrns]
        # First, save the final product
        hdulist.append(fits.ImageHDU(processor.unscramble(subtracted.mean(axis=0)), fits.Header({'EXTNAME': 'ENG', 'EXTVER': 1})))

        if include_eng == True:
              for fs_n in range(lrns):
                   hdulist.append(fits.ImageHDU(processor.unscramble(raw_reshaped[fs_n]), fits.Header({'EXTNAME': f'R{fs_n+1:02}', 'EXTVER': 1})))
              for index, fs_n in enumerate(range(lrns, lrns*2)):
                   hdulist.append(fits.ImageHDU(processor.unscramble(raw_reshaped[fs_n]), fits.Header({'EXTNAME': f'S{index+1:02}', 'EXTVER': 1})))
    else:
        processor = Processor(shift_delta=0, full_frame=True)
        raw_reshaped = data.reshape((lrns * 2, 512, 2048 * ndavgs))
        reshaped = raw_reshaped.astype(np.float32)
        averaged_samples = processor.ads_average(reshaped, ads_per_fowler=ndavgs)

        subtracted = averaged_samples[lrns:] - averaged_samples[:lrns]
        # First, save the final product
        hdulist.append(fits.ImageHDU(processor.unscramble(subtracted.mean(axis=0)), fits.Header({'EXTNAME': 'ENG', 'EXTVER': 1})))

        if include_eng == True:
             # Separate the samples
             basic_cols = np.arange(32, dtype=int)
             offsets = (np.arange(64) * (32 * ndavgs))[:,None]
             cols_in_ads = (basic_cols + offsets).ravel()
             if lrns == 1:
                  for n, ads in enumerate([raw_reshaped[0][:,cols_in_ads + (32 * sample)] for sample in range(ndavgs)]):
                       hdulist.append(fits.ImageHDU(processor.unscramble(ads), fits.Header({'EXTNAME': f'R01_{n+1}', 'EXTVER': 1})))
                  for n, ads in enumerate([raw_reshaped[1][:,cols_in_ads + (32 * sample)] for sample in range(ndavgs)]):
                       hdulist.append(fits.ImageHDU(processor.unscramble(ads), fits.Header({'EXTNAME': f'S01_{n+1}', 'EXTVER': 1})))
             else:
                  for fs_n in range(lrns):
                       for n, ads in enumerate([raw_reshaped[fs_n][:,cols_in_ads + (32 * sample)] for sample in range(ndavgs)]):
                             hdulist.append(fits.ImageHDU(processor.unscramble(ads), fits.Header({'EXTNAME': f'R{fs_n+1:02}_{n+1}', 'EXTVER': 1})))
                  for fs_n in range(lrns, lrns*2):
                       index = fs_n - lrns
                       for n, ads in enumerate([raw_reshaped[fs_n][:,cols_in_ads + (32 * sample)] for sample in range(ndavgs)]):
                             hdulist.append(fits.ImageHDU(processor.unscramble(ads), fits.Header({'EXTNAME': f'S{index+1:02}_{n+1}', 'EXTVER': 1})))

class TimingMeasurement:
    def __init__(self, name, value):
        series, _, num = name.partition('_')
        self.ident = (series, int(num))
        self.value = float(value)

def extract_timing(samples_header):
    extracted = sorted([TimingMeasurement(key, value) for key, value in samples_header.items()],
                       key=attrgetter('ident'))
    max_name_length = max(len(tm.ident[0]) for tm in extracted)
    header = fits.Header({
        'EXTNAME': 'TIMING',
        'EXTVER': 1
        })
    return fits.BinTableHDU(np.rec.array([(tm.ident[0], tm.ident[1], tm.value) for tm in extracted],
                                             formats=f'a{max_name_length},int16,float32',
                                             names='series,order,offset'),
                            header=header)

def create_hdulist(header, raw_path): 
    raw_name = os.path.basename(raw_path)
    try:
        pdu = header['PDU']
        datalabel = pdu['DATALABE']
        raw_cols = int(pdu['RAW_COLS'])
        raw_rows = int(pdu['RAW_ROWS'])
        dateobs = pdu.get('DATEOBS','')
        utstart = pdu['UTSTART']
        utend = pdu['UTEND']
        lnrs = int(pdu['LNRS'])
        ndavgs = int(pdu['NDAVGS'])
        exptime = float(pdu['EXPTIME'])
        reqtime = float(pdu['EXPREQ'])
        min_int = float(pdu['MIN_INT'])
        singleq = pdu.get('1Q', False)

        temp  = header['TEMPERATURE']
        temp1 = float(temp['TEMP IN1'])
        temp2 = float(temp['TEMP IN2'])

        voltage = float(pdu['DETBIAS'])

        p_mode = pdu['P_MODE']

        dcver = pdu['DCVER']

        fname = re.sub(r'[^\w]', '', f"{dateobs}{utstart}") + ".fits"

    except KeyError as e:
        raise ProcessingError(f"Processing {fname}: missing keyword {e.args[0]}")

    pdu = fits.PrimaryHDU(header=fits.Header({
        'DATALAB': datalabel,
        'DATE-OBS': dateobs,
        'UTSTART': utstart,
        'UTEND': utend,
        'LNRS': lnrs,
        'NDAVGS': ndavgs,
        'EXPTIME': exptime,
        'EXPREQ': reqtime,
        'MIN_INT': min_int,
        'DETTEMP': temp1,
        'DETBIAS': voltage,
        'P_MODE': p_mode,
        'DCVER' : dcver,
        'RAWNAME': raw_name,
        'DATMGVER': __version__
        }.items()))
    if singleq:
        pdu.header['SINGLEQ'] = True
    if 'FRAMES' in header:
        total_frames = lnrs * 2
        frame_rows = raw_rows // total_frames
        raw_data = np.empty((raw_rows * raw_cols,), dtype=np.uint16)
        loading = raw_data.reshape((total_frames, frame_rows * raw_cols))
        for n in range(total_frames):
            loading[n,:] = np.fromfile(f'{raw_path}.frame.{n}', dtype=np.uint16)
    else:
        raw_data_path = f'{raw_path}.raw'
        raw_data = np.memmap(raw_data_path, dtype=np.uint16).reshape((raw_rows, raw_cols))
    hdulist = fits.HDUList([pdu])

    if p_mode == 'SEP':
        include_eng = True
    else:
        include_eng = False
        
    save_processed_image(raw_data.reshape((raw_rows, raw_cols)), lnrs, ndavgs, exptime, hdulist, include_eng)
    # hdulist = fits.HDUList([pdu, procimage])
    if 'TIME_SAMPLES' in header:
        hdulist.append(extract_timing(header['TIME_SAMPLES']))
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


    

    def process_file(self, fname):
        # First, move the files to processing
        dm = self.datamov
        dm.move_group(dm.new, dm.processing, fname)

        self.logger.debug(f"Processing {fname}")

        try:
            rpath, header = decode_header(dm.processing, fname)

        # Create an output file and start populating it

            fitsname, hdulist = create_hdulist(header, rpath) 
            fits_path = dm.processing.full_path(fitsname)
            if os.access(fits_path, os.F_OK):
                raise ProcessingError(f"{fitsname} exists already")
            self.logger.debug(f" -> writing to {fits_path}")
            hdulist.writeto(fits_path)
            dm.move(dm.processing, dm.output, fitsname, error_allowed=False)

        except (NotImplementedError, ProcessingError, OSError) as e:
            self.logger.error(str(e))
            dm.move_group(dm.processing, dm.error, fname)
            raise ProcessingError(str(e))
        else:
            if self.keep:
                dm.move_group(dm.processing, dm.proc_raw, fname)

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

    setup_logging(INFO if not args['-d'] else DEBUG)

    dm = DataMover(DEFAULT_DATADIR, output_dir)

    raw = args['-r'] == True

    if args['batch']:
        batch_process(dm, keep, raw)
    elif args['daemon']:
        start_daemon(dm, keep)

if __name__ == '__main__':
    main()
