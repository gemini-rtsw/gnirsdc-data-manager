import numpy as np
from astropy.wcs import WCS
from astropy.coordinates import SkyCoord, FK5, ICRS
from astropy import units as u
from astropy.time import Time
from astropy.wcs.utils import fit_wcs_from_points

# Global dictionary to hold all WCS data in memory
wcs_data = {}
wcs_params_cache = {}

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
    # Extract the TCS context information
    track_ra = tcs_context['track_ra']
    track_dec = tcs_context['track_dec']
    track_frame = tcs_context['track_frame'].lower()  # Convert to lowercase
    track_equinox = tcs_context['track_equinox']
    time_tai = tcs_context['time_tai']

    # Create a SkyCoord object for the tracking position
    tracking_position = SkyCoord(ra=track_ra * u.deg, dec=track_dec * u.deg, frame=track_frame, equinox=Time(track_equinox, format='jyear'))

    # Convert the instrument offsets from millimeters to arcseconds
    instrument_offsets_arcsec = instrument_offsets * 1.61144

    # Convert the instrument offsets to sky coordinates using the TCS context
    sky_coords = tracking_position.spherical_offsets_by(instrument_offsets_arcsec[:, 0] * u.arcsec, instrument_offsets_arcsec[:, 1] * u.arcsec)

    # Convert the sky coordinates to ICRS
    sky_coords_icrs = sky_coords.transform_to(ICRS())

    # Separate pixel coordinates into x and y arrays
    x_pixel, y_pixel = pixel_coords[:, 0], pixel_coords[:, 1]

    # Fit the WCS transformation using astropy.wcs.utils.fit_wcs_from_points
    wcs = fit_wcs_from_points((x_pixel, y_pixel), sky_coords_icrs, proj_point='center')

    # Set the equinox and radesys attributes of the WCS object
    wcs.wcs.equinox = track_equinox
    wcs.wcs.radesys = track_frame

    return wcs

# Function to print the WCS data
def print_wcs_data(wcs):
    print(f"CTYPE1  = '{wcs.wcs.ctype[0]}'           / R.A. in tangent plane projection")
    print(f"CRPIX1  = {wcs.wcs.crpix[0]} / Ref pix of axis 1")
    print(f"CRVAL1  = {wcs.wcs.crval[0]} / RA at Ref pix in decimal degrees")
    print(f"CTYPE2  = '{wcs.wcs.ctype[1]}'           / DEC. in tangent plane projection")
    print(f"CRPIX2  = {wcs.wcs.crpix[1]} / Ref pix of axis 2")
    print(f"CRVAL2  = {wcs.wcs.crval[1]} / DEC at Ref pix in decimal degrees")
    print(f"CD1_1   = {wcs.wcs.cd[0, 0]} / WCS matrix element 1 1")
    print(f"CD1_2   = {wcs.wcs.cd[0, 1]} / WCS matrix element 1 2")
    print(f"CD2_1   = {wcs.wcs.cd[1, 0]} / WCS matrix element 2 1")
    print(f"CD2_2   = {wcs.wcs.cd[1, 1]} / WCS matrix element 2 2")
    print(f"EQUINOX = {wcs.wcs.equinox} / Equinox of coordinates")
    print(f"RADESYS = '{wcs.wcs.radesys}' / Coordinate frame")

# Function to choose the file based on port, camera, and ao
def choose_file(port, camera, ao):
    prefix = 'aognirs_' if ao else 'gnirs_'
    camera_type = 'long' if camera == 'long' else 'short'
    file_name = f"{prefix}{port}_{camera_type}.wcs"
    return file_name

# Function to process the file and print WCS data
def process_wcs_data(port, camera, ao, tcs_context):
    global wcs_params_cache

    file_name = choose_file(port, camera, ao)
    if file_name in wcs_data:
        if file_name not in wcs_params_cache:
            pixel_coords = wcs_data[file_name]['pixel_coords']
            tcs_coords = wcs_data[file_name]['tcs_coords']
            wcs = calculate_wcs_params(pixel_coords, tcs_coords, tcs_context)
            wcs_params_cache[file_name] = wcs
        else:
            wcs = wcs_params_cache[file_name]

        # Print the WCS data
        print(f"Processing file: {file_name}")
        print_wcs_data(wcs)

        # Optionally, print the world coordinates
        pixel_coords = wcs_data[file_name]['pixel_coords']
        world_coords = wcs.all_pix2world(pixel_coords, 1)
        print("World coordinates (RA, DEC):")
        print(world_coords)
    else:
        print(f"File {file_name} not found in memory. Please reload the files.")

# Function to reload all files
def reload_all_files():
    global wcs_params_cache
    load_all_files()
    wcs_params_cache = {}  # Clear the cache when reloading files
    print("All files reloaded.")

# Load all files initially
load_all_files()

# Example usage
tcs_context = {
    'track_ra': 231.657670833333,
    'track_dec': -20.8335166666667,
    'track_frame': 'FK5',
    'track_equinox': 2000.0,
    'time_tai': Time('2024-04-01T13:10:15.9').tai.mjd  # Convert to TAI MJD
}

port = 3
camera = 'short'
ao = False

process_wcs_data(port, camera, ao, tcs_context)