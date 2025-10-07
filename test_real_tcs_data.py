#!/usr/bin/env python3
import sys
from pathlib import Path

# Add the src directory to sys.path
sys.path.append(str(Path(__file__).parent / 'src'))

from src.wcs_utils import process_wcs_data, load_all_files

# Load all WCS files
load_all_files()

# Simulate the real TCS data based on your shell output
real_tcs_context = {
    'track_ra': "08:43:10.173",        # Real RA from shell output
    'track_dec': "+19:55:05.18",       # Real DEC from shell output  
    'track_frame': 'FK5',              # Real frame from shell output
    'track_equinox': 'J2000.00000000000000',  # Real equinox from shell output
    'time': 60663.5501248462,          # Assume similar MJD (this might be missing)
    'ra_offset': 0.0,                  # Default - might be missing from real data
    'dec_offset': 0.0,                 # Default - might be missing from real data
    'pm_ra': 0.0,                      # Default - might be missing from real data
    'pm_dec': 0.0,                     # Default - might be missing from real data
    'inst_iaa': 0.0,                   # Default - might be missing from real data
    'inst_pa': 0.0,                    # Real PA from shell output (was 0)
    'port': 3,                         # Assume port 3
    'camera': 'short',                 # Assume short camera
    'ao': 'park-pos.'                  # Assume parked AO
}

print("Testing with real TCS data format...")
print(f"RA: {real_tcs_context['track_ra']}")
print(f"DEC: {real_tcs_context['track_dec']}")
print(f"Frame: {real_tcs_context['track_frame']}")
print(f"Equinox: {real_tcs_context['track_equinox']}")
print(f"PA: {real_tcs_context['inst_pa']}")

try:
    # Process WCS data
    wcs = process_wcs_data(
        real_tcs_context['port'], 
        real_tcs_context['camera'], 
        real_tcs_context['ao'], 
        real_tcs_context
    )
    
    print("\n✓ WCS calculation succeeded!")
    print(f"CRVAL1 = {wcs.wcs.crval[0]}")
    print(f"CRVAL2 = {wcs.wcs.crval[1]}")
    print(f"CRPIX1 = {wcs.wcs.crpix[0]}")
    print(f"CRPIX2 = {wcs.wcs.crpix[1]}")
    
except Exception as e:
    print(f"\n✗ WCS calculation failed: {e}")
    import traceback
    traceback.print_exc()

# Now test with missing time field (common issue)
print("\n" + "="*50)
print("Testing with missing time field...")

real_tcs_context_no_time = real_tcs_context.copy()
del real_tcs_context_no_time['time']

try:
    wcs = process_wcs_data(
        real_tcs_context_no_time['port'], 
        real_tcs_context_no_time['camera'], 
        real_tcs_context_no_time['ao'], 
        real_tcs_context_no_time
    )
    print("✓ WCS calculation succeeded without time!")
except Exception as e:
    print(f"✗ WCS calculation failed without time: {e}")

# Test with missing optional fields
print("\n" + "="*50)
print("Testing with minimal TCS data (only required fields)...")

minimal_tcs_context = {
    'track_ra': "08:43:10.173",
    'track_dec': "+19:55:05.18",
    'track_frame': 'FK5',
    'track_equinox': 'J2000.00000000000000',
    'time': 60663.5501248462,
    'port': 3,
    'camera': 'short',
    'ao': 'park-pos.'
}

try:
    wcs = process_wcs_data(
        minimal_tcs_context['port'], 
        minimal_tcs_context['camera'], 
        minimal_tcs_context['ao'], 
        minimal_tcs_context
    )
    print("✓ WCS calculation succeeded with minimal data!")
except Exception as e:
    print(f"✗ WCS calculation failed with minimal data: {e}")
    import traceback
    traceback.print_exc()

