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

# Define the real header values as tcs_context
tcs_context = {
    'track_ra': "04:33:26.08",          # RA in hourangle string format
    'track_dec': "+22:45:25.42",         # DEC in degrees string format
    'track_frame': 'FK5',
    'track_equinox': 'J2000.0',
    'time': 60571.5623074667,            # MJD of observation start
    'ra_offset': -2.47726331562134,      # Telescope offset in RA in arcsec
    'dec_offset': 0.619344902202265,      # Telescope offset in DEC in arcsec
    'pm_ra': 0.0,                        # Proper Motion in RA (arcsec/year)
    'pm_dec': 0.0                        # Proper Motion in Dec (arcsec/year)    
}

# Define parameters
port = 3
camera = 'short'
ao = 'OUT'

# Process WCS data
wcs = process_wcs_data(port, camera, ao, tcs_context)

# Print the calculated WCS header
print("Calculated WCS Header:")
print(f"CTYPE1  = '{wcs.wcs.ctype[0]}'")
print(f"CRPIX1  = {wcs.wcs.crpix[0]}")
print(f"CRVAL1  = {wcs.wcs.crval[0]}")
print(f"CTYPE2  = '{wcs.wcs.ctype[1]}'")
print(f"CRPIX2  = {wcs.wcs.crpix[1]}")
print(f"CRVAL2  = {wcs.wcs.crval[1]}")
print(f"CD1_1   = {wcs.wcs.cd[0, 0]}")
print(f"CD1_2   = {wcs.wcs.cd[0, 1]}")
print(f"CD2_1   = {wcs.wcs.cd[1, 0]}")
print(f"CD2_2   = {wcs.wcs.cd[1, 1]}")
print(f"EQUINOX = {wcs.wcs.equinox}")

# Print the real FITS header values for comparison
print("\nReal FITS Header Values:")
print("CTYPE1  = 'RA---TAN'")
print("CRPIX1  = 496.09046165875")
print("CRVAL1  = 68.3552197363359")
print("CTYPE2  = 'DEC--TAN'")
print("CRPIX2  = 629.961909100396")
print("CRVAL2  = 22.7510440262337")
print("CD1_1   = -3.62424139562799E-05")
print("CD1_2   = -2.18690840336252E-05")
print("CD2_1   = 2.16030382479371E-05")
print("CD2_2   = -3.68117762385558E-05")
print("EQUINOX = 2000.0")
