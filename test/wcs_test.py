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

# Define the real header values as tcs_context for N20241219S0088.fits
tcs_context = {
    'track_ra': "00:45:28.81",         # RA in hourangle string format (converted from 11.3700416666667)
    'track_dec': "+41:54:09.90",       # DEC in degrees string format (converted from 41.90275)
    'track_frame': 'FK5',
    'track_equinox': 'J2000.0',
    'time': 60663.3445497426,          # MJD of observation start (MJD_OBS)
    'ra_offset': 1.48031131656736,     # Telescope offset in RA in arcsec (RAOFFSET)
    'dec_offset': 0.0344496035053328,  # Telescope offset in DEC in arcsec (DECOFFSE)
    'pm_ra': 0.0,                      # Proper Motion in RA (arcsec/year) (PMRA)
    'pm_dec': 0.0,                     # Proper Motion in Dec (arcsec/year) (PMDEC)
    'inst_pa': 89.818 - 292.22,        # IAA - PA (IAA - PA)
    # Mount pointing origin values (in arcseconds)
    'mount_origin_x': -0.778508,       # Mount pointing origin in X (arcsec)
    'mount_origin_y': 15.0837          # Mount pointing origin in Y (arcsec)
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
print("\nReal FITS Header Values for N20241219S0088.fits:")
print("CTYPE1  = 'RA---TAN'")
print("CRPIX1  = 496.090823676464")
print("CRVAL1  = 11.3740732760405")
print("CTYPE2  = 'DEC--TAN'")
print("CRPIX2  = 629.961947165382")
print("CRVAL2  = 41.9087958888901")
print("CD1_1   = 3.88344523031505E-05")
print("CD1_2   = 1.66870209963025E-05")
print("CD2_1   = -1.65014646994829E-05")
print("CD2_2   = 3.94268801298063E-05")
print("EQUINOX = 2000.0")
