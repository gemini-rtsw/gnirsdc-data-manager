import numpy as np
from astropy.wcs import WCS
from astropy.coordinates import SkyCoord, FK5, ICRS
from astropy import units as u
from astropy.time import Time
from astropy.wcs.utils import fit_wcs_from_points
import logging
from logging_config import IRDC_DEBUG, PRINT

from gnirsutil import DEBUG_MODE

import re
from astropy.coordinates import Angle
from datetime import datetime
from astropy.time import Time

from gnirsutil import config, config_mode, DEBUG_MODE


from astropy.coordinates import Angle
import re

# Global dictionary to hold all WCS data in memory
wcs_data = {}
wcs_params_cache = {}

# Get a logger for this module
logger = logging.getLogger(__name__)


# Function to read a WCS file and return the pixel coordinates and instrument offsets
def read_wcs_file(file_path):
    data = np.loadtxt(file_path)
    pixel_coords = data[:, :2]
    instrument_offsets = data[:, 2:]  # Assuming the last two columns are instrument offsets in millimeters
    return pixel_coords, instrument_offsets

# Function to load all WCS files into memory
def load_all_files():
    global wcs_data
    files = [
        'aognirs_1_long.wcs', 'aognirs_3_long.wcs', 'aognirs_5_long.wcs',
        'gnirs_1_long.wcs', 'gnirs_3_long.wcs', 'gnirs_5_long.wcs',
        'aognirs_1_short.wcs', 'aognirs_3_short.wcs', 'aognirs_5_short.wcs',
        'gnirs_1_short.wcs', 'gnirs_3_short.wcs', 'gnirs_5_short.wcs'
    ]
    base_dir = '../conf/wcs/'  

    for file_name in files:
        file_path = base_dir + file_name
        pixel_coords, tcs_coords = read_wcs_file(file_path)
        wcs_data[file_name] = {
            'pixel_coords': pixel_coords,
            'tcs_coords': tcs_coords
        }





def calculate_wcs_params(pixel_coords, instrument_offsets, tcs_context):
    # Extract and convert the TCS context information
    track_ra = Angle(tcs_context['track_ra'], unit=u.hourangle).deg
    track_dec = Angle(tcs_context['track_dec'], unit=u.deg).deg
    track_frame = str(tcs_context['track_frame']).lower()  # Convert to lowercase
    
    # Log the extracted values using PRINT level
    logger.log(PRINT, f"Extracted track_ra: {track_ra} degrees")
    logger.log(PRINT, f"Extracted track_dec: {track_dec} degrees")
    logger.log(PRINT, f"Extracted track_frame: {track_frame}")

    # Updated regex to handle more decimal places
    epoch_match = re.match(r'J?(\d+(?:\.\d+)?)', tcs_context['track_equinox'])
    if epoch_match:
        track_equinox = float(epoch_match.group(1))
    else:
        # Handle the case when the telescope is parked or the format is unexpected
        track_equinox = 0.0
    
    # Log the extracted track_equinox
    logger.log(PRINT, f"Extracted track_equinox: {track_equinox}")

    time_mjd = float(tcs_context['time'])

    # Create an obstime object from the MJD time
    obstime = Time(time_mjd, format='mjd', scale='tai')  # Ensure correct time scale

    # Get proper motion from TCS context, default to 0 if not provided
    pm_ra = tcs_context.get('pm_ra', 0.0) * u.arcsec / u.yr
    pm_dec = tcs_context.get('pm_dec', 0.0) * u.arcsec / u.yr

    # Get telescope offsets in arcseconds
    ra_offset = tcs_context.get('ra_offset', 0.0) * u.arcsec
    dec_offset = tcs_context.get('dec_offset', 0.0) * u.arcsec

    # Get the instrument position angle
    inst_pa = Angle(tcs_context.get('inst_pa', 0.0), unit=u.deg).deg

    # Create a SkyCoord object for the tracking position with obstime and proper motion
    tracking_position = SkyCoord(
        ra=track_ra * u.deg,
        dec=track_dec * u.deg,
        pm_ra_cosdec=pm_ra,
        pm_dec=pm_dec,
        frame=track_frame,
        equinox=Time(track_equinox, format='jyear'),
        obstime=obstime
    )

    # scale the instrument offsets from mm to arcseconds
    mm_to_arcsec_scale = float(config['DEFAULT']['MM_TO_ARCSEC_SCALE'])
    instrument_offsets = instrument_offsets * mm_to_arcsec_scale
    
    # Center the instrument offsets
    center = np.mean(instrument_offsets, axis=0)
    centered_offsets = instrument_offsets - center

    # Rotate centered instrument offsets by inst_pa
    rotation_angle = np.radians(inst_pa)
    rotation_matrix = np.array([
        [np.cos(rotation_angle), -np.sin(rotation_angle)],
        [np.sin(rotation_angle), np.cos(rotation_angle)]
    ])
    rotated_offsets = centered_offsets @ rotation_matrix.T

    # Translate back
    final_offsets = rotated_offsets + center

    # Apply units to final offsets
    delta_ra = final_offsets[:, 0] * u.arcsec
    delta_dec = final_offsets[:, 1] * u.arcsec

    # Apply final instrument offsets to the tracking position
    sky_coords = tracking_position.spherical_offsets_by(
        delta_ra,
        delta_dec
    )

    # Convert the sky coordinates to ICRS frame
    sky_coords_icrs = sky_coords.transform_to(ICRS())

    # Separate pixel coordinates
    x_pixel, y_pixel = pixel_coords[:, 0], pixel_coords[:, 1]

    # Get CRPA
    crpa = -52.6559717229396  # From FITS header
    
    # Create rotation matrix
 #   rot_angle = np.radians(crpa)
 #   rot_matrix = np.array([
 #       [np.cos(rot_angle), -np.sin(rot_angle)],
 #       [np.sin(rot_angle), np.cos(rot_angle)]
 #   ])
    
    # Rotate pixel coordinates
#    pixel_coords_rotated = np.dot(rot_matrix, pixel_coords.T).T
    
    # Now call fit_wcs_from_points with rotated coordinates
    wcs = fit_wcs_from_points(
#        (pixel_coords_rotated[:, 0], pixel_coords_rotated[:, 1]),
        (x_pixel, y_pixel), 
        sky_coords_icrs
 #       projection='TAN'
    )

    # Set equinox and radesys
    wcs.wcs.equinox = track_equinox
    wcs.wcs.radesys = track_frame.upper()

    # Log the CD matrix 
    logger.log(IRDC_DEBUG, f"CD matrix after rotation:")
    logger.log(IRDC_DEBUG, f"CD1_1 = {wcs.wcs.cd[0, 0]}")
    logger.log(IRDC_DEBUG, f"CD1_2 = {wcs.wcs.cd[0, 1]}")
    logger.log(IRDC_DEBUG, f"CD2_1 = {wcs.wcs.cd[1, 0]}")
    logger.log(IRDC_DEBUG, f"CD2_2 = {wcs.wcs.cd[1, 1]}")

    print(f"inst_pa from context: {inst_pa}")
    print(f"rotation_angle (radians): {rotation_angle}")
    print(f"Sample original offset: {instrument_offsets[0]}")
    print(f"Sample rotated offset: {rotated_offsets[0]}")

    return wcs




# Function to print the WCS data
def print_wcs_data(wcs):
    logger.log(IRDC_DEBUG, f"CTYPE1  = '{wcs.wcs.ctype[0]}'           / R.A. in tangent plane projection")
    logger.log(IRDC_DEBUG, f"CRPIX1  = {wcs.wcs.crpix[0]} / Ref pix of axis 1")
    logger.log(IRDC_DEBUG, f"CRVAL1  = {wcs.wcs.crval[0]} / RA at Ref pix in decimal degrees")
    logger.log(IRDC_DEBUG, f"CTYPE2  = '{wcs.wcs.ctype[1]}'           / DEC. in tangent plane projection")
    logger.log(IRDC_DEBUG, f"CRPIX2  = {wcs.wcs.crpix[1]} / Ref pix of axis 2")
    logger.log(IRDC_DEBUG, f"CRVAL2  = {wcs.wcs.crval[1]} / DEC at Ref pix in decimal degrees")
    logger.log(IRDC_DEBUG, f"CD1_1   = {wcs.wcs.cd[0, 0]} / WCS matrix element 1 1")
    logger.log(IRDC_DEBUG, f"CD1_2   = {wcs.wcs.cd[0, 1]} / WCS matrix element 1 2")
    logger.log(IRDC_DEBUG, f"CD2_1   = {wcs.wcs.cd[1, 0]} / WCS matrix element 2 1")
    logger.log(IRDC_DEBUG, f"CD2_2   = {wcs.wcs.cd[1, 1]} / WCS matrix element 2 2")
    logger.log(IRDC_DEBUG, f"EQUINOX = {wcs.wcs.equinox} / Equinox of coordinates")
    logger.log(IRDC_DEBUG, f"RADESYS = '{wcs.wcs.radesys}' / Coordinate frame")

# Function to choose the file based on port, camera, and ao
def choose_file(port, camera, ao):
    prefix = 'aognirs_' if ao == 'IN' else 'gnirs_'
    camera_type = 'long' if 'long' in camera.lower() else 'short'
    file_name = f"{prefix}{port}_{camera_type}.wcs"
    return file_name

# Function to process the file and print WCS data
def process_wcs_data(port, camera, ao, tcs_context):

    try:
        file_name = choose_file(port, camera, ao)
        if file_name in wcs_data:
            pixel_coords = wcs_data[file_name].get('pixel_coords')
            tcs_coords = wcs_data[file_name].get('tcs_coords')
            
            if pixel_coords is None or tcs_coords is None or not tcs_context:
                raise ValueError("Missing required parameters for WCS calculation")
            
            wcs = calculate_wcs_params(pixel_coords, tcs_coords, tcs_context)

            
            if DEBUG_MODE:
                # Print the WCS data
                logger.log(IRDC_DEBUG, f"Processing file: {file_name}")
                print_wcs_data(wcs)

                # Print the world coordinates
                pixel_coords = wcs_data[file_name].get('pixel_coords')
                if pixel_coords is not None:
                    world_coords = wcs.all_pix2world(pixel_coords, 1)
                    logger.log(IRDC_DEBUG, "World coordinates (RA, DEC):")
                    logger.log(IRDC_DEBUG, str(world_coords))

            return wcs  # Return the WCS object
        else:
            raise ValueError(f"File {file_name} not found in memory. Please reload the files.")
    except Exception as e:
        logger.error(f"Error processing WCS data: {str(e)}")
        # Return a default WCS object with correct types
        return WCS(naxis=2)

# Function to reload all files
def reload_all_files():
    global wcs_params_cache
    load_all_files()
    wcs_params_cache = {}  # Clear the cache when reloading files
    logger.log(IRDC_DEBUG, "All files reloaded.")

# Load all files initially
load_all_files()

# Example usage
'''
tcs_context = {
    'track_ra': 68.3586666666667,  # RA in degrees
    'track_dec': 22.7570611111111, # DEC in degrees
    'track_frame': 'FK5',
    'track_equinox': 'J2000.0',
    'time': 60571.5623074667      # MJD of observation start
}

port = 3
camera = 'short'
ao = 'OUT'

wcs = process_wcs_data(port, camera, ao, tcs_context)
'''
