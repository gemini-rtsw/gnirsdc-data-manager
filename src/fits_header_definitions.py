from astropy.io import fits
import numpy as np
import re
import os
import uuid
from wcs_utils import process_wcs_data
from gnirsutil import config, config_mode, DEBUG_MODE


def generate_new_filepath(fits_path):
    base, ext = os.path.splitext(fits_path)
    new_filename = f"{base}_{uuid.uuid4()}{ext}"
    return new_filename

def generate_new_filename():
    new_filename = f"{uuid.uuid4()}"
    return new_filename

#def define_hdu_list(header, data_label = None, dc_commit = None, lib_commit = None):
def define_hdu_list(header, dc_commit = None, lib_commit = None):
    try:

        # extract raw header data
        pdu = header['PDU']
        rawlabel = pdu['RAWLABEL']
        data_label = pdu['LABEL']
        raw_cols = int(pdu['RAW_COLS'])
        raw_rows = int(pdu['RAW_ROWS'])
        dateobs = pdu.get('DATEOBS','')
        utstart = pdu['UTSTART']
        utend = pdu['UTEND']
        lnrs = int(pdu['LNRS'])
        ndavgs = int(pdu['NDAVGS'])
        exptime = round(float(pdu['EXPTIME']), 3)
        reqtime = float(pdu['EXPREQ'])
        min_int = float(pdu['MIN_INT'])
        singleq = pdu.get('1Q', False)

        temp  = header['TEMPERATURE']
        temp1 = float(temp['TEMP IN1'])
        temp2 = float(temp['TEMP IN2'])

        voltage = float(pdu['DETBIAS'])

        p_mode = pdu['P_MODE']

        coadds = pdu['COADDS']

        dcver = pdu['DCVER']


        # TCS context information
        tcs_ra = pdu.get('TCS_RA', '')
        tcs_dec = pdu.get('TCS_DEC', '')
        tcs_frame = pdu.get('TCS_FRAME', '')
        tcs_equinox = pdu.get('TCS_EQUINOX', '')
        tcs_time = pdu.get('TCS_TIME', '')
        tcs_port = pdu.get('TCS_PORT', '')
        tcs_camera = pdu.get('TCS_CAMERA', '')
        tcs_ao = pdu.get('TCS_AO', '')
        tcs_inst_pa = pdu.get('TCS_INST_PA', '')
        tcs_ra_offset = pdu.get('TCS_RA_OFFSET', '')
        tcs_dec_offset = pdu.get('TCS_DEC_OFFSET', '')
        tcs_pm_ra = pdu.get('TCS_PM_RA', '')
        tcs_pm_dec = pdu.get('TCS_PM_DEC', '')
        tcs_inst_iaa = pdu.get('TCS_INST_IAA', '')

        # Check if TCS context is missing
        tcs_context_missing = any(value == '' for value in [
            tcs_ra, tcs_dec, tcs_frame, tcs_equinox, tcs_time, 
            tcs_port, tcs_camera, tcs_ao, tcs_inst_pa, tcs_ra_offset,
            tcs_dec_offset, tcs_pm_ra, tcs_pm_dec, tcs_inst_iaa
        ])

        if not tcs_context_missing:
            tcs_context = {
                'track_ra': tcs_ra,
                'track_dec': tcs_dec,
                'track_frame': tcs_frame,
                'track_equinox': tcs_equinox,
                'time': float(tcs_time),
                'port': int(tcs_port),
                'camera': tcs_camera,
                'ao': tcs_ao,
                'inst_pa': float(tcs_inst_pa),
                'ra_offset': float(tcs_ra_offset),
                'dec_offset': float(tcs_dec_offset),
                'pm_ra': float(tcs_pm_ra),
                'pm_dec': float(tcs_pm_dec),
                'inst_iaa': float(tcs_inst_iaa)
            }
        else:
            tcs_context = None
            print("Warning: TCS context is missing or incomplete.")

        fname = re.sub(r'[^\w]', '', f"{dateobs}{utstart}") + ".fits"

    except KeyError as e:
        raise KeyError(f"Processing {fname}: missing keyword {e.args[0]}")

    # Create the header
    fits_header = fits.Header()

    # Standard keywords with the correct boolean and integer values and comments
    fits_header['SIMPLE']   = (True, 'file does conform to FITS standard')
    fits_header['BITPIX']   = (16, 'number of bits per data pixel')
    fits_header['NAXIS']    = (0, 'number of data axes')
    fits_header['EXTEND']   = (True, 'FITS dataset may contain extensions')
    fits_header['INSTRUME'] = ('GNIRS', 'Instrument used to acquire data')

    # Adding other header keywords related to your data
#    fits_header['DATALAB']  = (data_label, 'DHS Data Label')
    fits_header['DATE-OBS'] = (dateobs, 'UT Date of observation (YYYY-MM-DD)')
    fits_header['TIME-OBS'] = (utstart, 'Time of observation')
    fits_header['UTSTART']  = (utstart, 'UT at observation start')
    fits_header['UTEND']    = (utend, 'UT at observation end')
    fits_header['LNRS']     = (lnrs, '# of fowler samples')
    fits_header['NDAVGS']   = (ndavgs, '# of digital averages')
    fits_header['EXPTIME']  = (exptime, 'integration time (seconds)')
    fits_header['MIN_INT']  = (min_int, 'minimum integration time (seconds)')
    fits_header['DSRDTEMP']  = (temp1, 'desired detector temperature (K)')
    fits_header['DETTEMP']  = (temp1, 'detector temperature (K)')
    fits_header['DETBIAS']  = (voltage,'Achieved Detector Bias')
    fits_header['P_MODE']   = (p_mode, 'proc mode (stare, sep)')
    fits_header['DCVER1']    = (dcver, 'library build tag')
    fits_header['DCVER2']    = (lib_commit, 'library git commit')
    fits_header['DCVER3']    = (dc_commit, 'DC git commit')
    fits_header['COADDS']   = (coadds, '# of coadded images')
    fits_header['ARRAYID']   = ('SN7638228.1.3','ID # of array')
    fits_header['ARRAYTYP']  = ('ALADDIN_III_1024','ALADDIN II or ALADDIN III')
    fits_header['CONID']     = ('ARC-III','Detector controller')
    fits_header['ROWS']     = (1024,'array rows')
    fits_header['COLS']     = (1024,'array cols')


    fits_header.insert(4, ('COMMENT', "FITS (Flexible Image Transport System) format is defined in 'Astronomy"))
    fits_header.insert(5, ('COMMENT', "and Astrophysics', volume 376, page 359; bibcode: 2001A&A...376..359H"))

    # Add WCS information to the primary header only if TCS context is not missing
    if not tcs_context_missing:
        wcs = process_wcs_data(tcs_port, tcs_camera, tcs_ao, tcs_context)
        
        fits_header.update(wcs.to_header())
    else:
        print("Warning: WCS information not added due to missing TCS context.")

    # Add READMODE to the header
    read_modes = eval(config[config_mode].get('READ_MODES', '{}'))
    print(f"lnrs: {lnrs}, ndavgs: {ndavgs}")
    print(f"read_modes keys: {read_modes.keys()}")

    # Convert lnrs and ndavgs to strings and create the key
    key = f"({lnrs}, {ndavgs})"
    readmode = read_modes.get(key, 'Unknown')

    fits_header['READMODE'] = (readmode, 'Detector read mode')
    print(f"Final readmode: {readmode}")

    extention_header = fits.Header({
        'EXTNAME': 'SCI',
        'EXTVER': 1,
        'DROINUM': 0,
        'LOWROW': 0,
        'LOWCOL': 0,
        'HIROW': 1023,
        'HICOL': 1023,
        'FRMNAME': f'{data_label}:0',
        'FRAMEID': '0',
        'DATATYPE': ' '
    })


    # Create the Primary HDU with the header
    pdu = fits.PrimaryHDU(header=fits_header)#, data=data)
    

    if data_label:
        fname = data_label


    hdulist = fits.HDUList([pdu])


    return hdulist, extention_header, lnrs, ndavgs, raw_cols, raw_rows, coadds, exptime, p_mode, fname

