# test_wcs.py

import sys
from pathlib import Path

# Add the parent directory to sys.path to allow importing from src
sys.path.append(str(Path(__file__).parent.parent))

# Add the src directory to sys.path
sys.path.append(str(Path(__file__).parent.parent / 'src'))

from src.wcs_utils import process_wcs_data, load_all_files


# Load all WCS files
load_all_files()

# Define the real header values as tcs_context for N20241219S0210.fits
tcs_context = {
    'track_ra': "10:12:41.22",         # RA in hourangle string format (converted from 153.171733333333)
    'track_dec': "+21:55:56.09",       # DEC in degrees string format (converted from 21.9322472222222)
    'track_frame': 'FK5',
    'track_equinox': 'J2000.0',
    'time': 60663.5501248462,          # MJD of observation start (MJD_OBS)
    'ra_offset': 2.82962477863191,     # Telescope offset in RA in arcsec (RAOFFSET)
    'dec_offset': -0.490166004284015,  # Telescope offset in DEC in arcsec (DECOFFSE)
    'pm_ra': 1.86856864913779E-05,     # Proper Motion in RA (arcsec/year) (PMRA)
    'pm_dec': -0.000774999987160837,   # Proper Motion in Dec (arcsec/year) (PMDEC)
    'inst_iaa': 89.818,                # IAA
    'inst_pa': 87.38,                   # PA
    # Mount pointing origin values (in arcseconds)
    'mount_origin_x': -1.49941,        # Mount pointing origin in X (arcsec)
    'mount_origin_y': 15.0983,          # Mount pointing origin in Y (arcsec)
    'coord_epoch': 2000.0,             # Epoch of coordinates (EPOCH)
    'obs_epoch': 2024.96659012418      # Epoch of observation (OBSEPOCH)
}

# Define parameters
port = 3
camera = 'short'
ao = 'park-pos.'

# Process WCS data
wcs = process_wcs_data(port, camera, ao, tcs_context)

# Print the calculated WCS header
print("Calculated WCS Header:")
print(f"CTYPE1  = '{wcs.wcs.ctype[0]}'")
print(f"CTYPE2  = '{wcs.wcs.ctype[1]}'")
print(f"CRVAL1  = {wcs.wcs.crval[0]}")
print(f"CRVAL2  = {wcs.wcs.crval[1]}")
print(f"CRPIX1  = {wcs.wcs.crpix[0]}")
print(f"CRPIX2  = {wcs.wcs.crpix[1]}")
print(f"CD1_1   = {wcs.wcs.cd[0, 0]}")
print(f"CD1_2   = {wcs.wcs.cd[0, 1]}")
print(f"CD2_1   = {wcs.wcs.cd[1, 0]}")
print(f"CD2_2   = {wcs.wcs.cd[1, 1]}")
print(f"EQUINOX = {wcs.wcs.equinox}")

# Print the real FITS header values for comparison
print("\nReal FITS Header Values for N20241219S0210.fits:")
print("CTYPE1  = 'RA---TAN'")
print("CTYPE2  = 'DEC--TAN'")
print("CRVAL1  = 153.172736591151")
print("CRVAL2  = 21.9255289007877")
print("CRPIX1  = 496.090514892775")
print("CRPIX2  = 629.961888123742")
print("CD1_1   = -4.21735715333856E-05")
print("CD1_2   = 1.42335600936915E-06")
print("CD2_1   = -1.33992373834336E-06")
print("CD2_2   = -4.27957141820222E-05")
print("EQUINOX = 2000.0")
