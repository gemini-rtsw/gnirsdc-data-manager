from astropy.io import fits
import numpy as np
import re
import os
import uuid
from wcs_utils import process_wcs_data


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
        exptime = float(pdu['EXPTIME'])
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
        tcs_ra = pdu['TCS_RA']
        tcs_dec = pdu['TCS_DEC']
        tcs_frame = pdu['TCS_FRAME']
        tcs_equinox = pdu['TCS_EQUINOX']
        tcs_tai = pdu['TCS_TAI']
        tcs_port = pdu['TCS_PORT']
        tcs_camera = pdu['TCS_CAMERA']
        tcs_ao = pdu['TCS_AO']

        tcs_context = {
            'track_ra': float(tcs_ra),
            'track_dec': float(tcs_dec),
            'track_frame': tcs_frame,
            'track_equinox': float(tcs_equinox),
            'time_tai': float(tcs_tai)
        }

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
    fits_header['DATALAB']  = (data_label, 'DHS Data Label')
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
    fits_header['ARRAYID']   = ('SN7638228.1.2','ID # of array')
    fits_header['ARRAYTYP']  = ('ALADDIN_III_1024','ALADDIN II or ALADDIN III')
    fits_header['CONID']     = ('ARC-III','Detector controller')
    fits_header['ROWS']     = (1024,'array rows')
    fits_header['COLS']     = (1024,'array cols')


    fits_header.insert(4, ('COMMENT', "FITS (Flexible Image Transport System) format is defined in 'Astronomy"))
    fits_header.insert(5, ('COMMENT', "and Astrophysics', volume 376, page 359; bibcode: 2001A&A...376..359H"))

    wcs = process_wcs_data(tcs_port, tcs_camera, tcs_ao, tcs_context)

    # Add WCS information to the primary header
    fits_header.update(wcs.to_header())



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

