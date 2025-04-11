#!/usr/bin/env python3
"""
A simple script to calculate CRPIX values from target coordinates and WCS parameters.
"""

from astropy.io import fits
from astropy import wcs
import numpy

def calculate_crpix(header_data, target_ra, target_dec, apply_offsets=True):
    """
    Calculate CRPIX values for a given target position and WCS parameters.
    
    Parameters:
    -----------
    header_data : dict
        Dictionary containing WCS parameters (CD matrix, CRVAL, existing CRPIX)
    target_ra : float
        Target Right Ascension in degrees
    target_dec : float
        Target Declination in degrees
    apply_offsets : bool, optional
        Whether to apply offsets and proper motion, default is True
        
    Returns:
    --------
    dict
        Dictionary containing the calculated CRPIX values and related information
    """
    # Create a WCS object with the header data
    hdr = fits.Header()
    for key, value in header_data.items():
        hdr[key] = value
    w = wcs.WCS(hdr)
    
    # Apply offsets and proper motion if requested
    expected_ra = target_ra
    expected_dec = target_dec
    
    if apply_offsets and all(k in header_data for k in ['RAOFFSET', 'DECOFFSE', 'EPOCH', 'OBSEPOCH', 'PMRA', 'PMDEC']):
        # Get offsets and proper motion data
        raoffset = header_data['RAOFFSET']
        decoffset = header_data['DECOFFSE']  # Note the typo in keyword
        pmra = header_data['PMRA']
        pmdec = header_data['PMDEC']
        
        # Calculate epoch difference for proper motion
        epochobs = header_data['OBSEPOCH']
        epoch = header_data['EPOCH']
        dt = epochobs - epoch
        
        # Apply offsets and proper motion
        expected_ra = target_ra + raoffset/3600.0 + pmra*15.0/3600.0*dt
        expected_dec = target_dec + decoffset/3600.0 + pmdec/3600.0*dt
    
    # Calculate the pixel coordinates for the expected position
    # This will be our new CRPIX values if we want to redefine the WCS
    # with the reference point at the target position
    calculated_crpix_x, calculated_crpix_y = w.wcs_world2pix(expected_ra, expected_dec, 1)
    
    # Return the results
    results = {
        'input_target_ra': target_ra,
        'input_target_dec': target_dec,
        'expected_ra': expected_ra,
        'expected_dec': expected_dec,
        'calculated_crpix_x': calculated_crpix_x,
        'calculated_crpix_y': calculated_crpix_y,
        'original_crpix_x': header_data.get('CRPIX1'),
        'original_crpix_y': header_data.get('CRPIX2'),
        'crval_ra': header_data.get('CRVAL1'),
        'crval_dec': header_data.get('CRVAL2')
    }
    
    return results

def test_calculate_crpix():
    """Test the CRPIX calculation function with 2MASS header data."""
    # Header values from 2MASS J10124120+2155561 observation (N20241219S0210.fits)
    header_data = {
        'RA': 153.171733333333,            # Target Right Ascension (deg)
        'DEC': 21.9322472222222,           # Target Declination (deg)
        'EPOCH': 2000.0,                   # Coordinate epoch
        'RAOFFSET': 2.82962477863191,      # RA offset (arcsec)
        'DECOFFSE': -0.490166004284015,    # DEC offset (arcsec) - note typo in keyword
        'PMRA': 1.86856864913779E-05,      # Proper motion in RA (sec/year)
        'PMDEC': -0.000774999987160837,    # Proper motion in DEC (arcsec/year)
        'OBSEPOCH': 2024.96659012418,      # Epoch of observation
        
        # WCS parameters
        'CTYPE1': 'RA---TAN',              # Projection type for RA
        'CRPIX1': 496.090514892775,        # Reference pixel X
        'CRVAL1': 153.172736591151,        # RA at reference pixel (deg)
        'CTYPE2': 'DEC--TAN',              # Projection type for DEC
        'CRPIX2': 629.961888123742,        # Reference pixel Y
        'CRVAL2': 21.9255289007877,        # DEC at reference pixel (deg)
        'CD1_1': -4.21735715333856E-05,    # CD matrix element 1,1
        'CD1_2': 1.42335600936915E-06,     # CD matrix element 1,2
        'CD2_1': -1.33992373834336E-06,    # CD matrix element 2,1
        'CD2_2': -4.27957141820222E-05,    # CD matrix element 2,2
    }
    
    # Calculate CRPIX for the target position
    results = calculate_crpix(header_data, header_data['RA'], header_data['DEC'])
    
    # Print the results
    print("CRPIX Calculation Test")
    print("---------------------\n")
    
    print(f"Target RA: {results['input_target_ra']:.8f} deg")
    print(f"Target DEC: {results['input_target_dec']:.8f} deg")
    
    if results['expected_ra'] != results['input_target_ra']:
        print(f"\nAfter applying offsets and proper motion:")
        print(f"Expected RA: {results['expected_ra']:.8f} deg")
        print(f"Expected DEC: {results['expected_dec']:.8f} deg")
    
    print(f"\nCalculated CRPIX for target: ({results['calculated_crpix_x']:.3f}, {results['calculated_crpix_y']:.3f})")
    print(f"Original CRPIX from header: ({results['original_crpix_x']:.3f}, {results['original_crpix_y']:.3f})")
    print(f"Difference: ({abs(results['calculated_crpix_x'] - results['original_crpix_x']):.3f}, {abs(results['calculated_crpix_y'] - results['original_crpix_y']):.3f})")
    
    # Also test calculating CRPIX for the CRVAL coordinates
    crval_results = calculate_crpix(header_data, header_data['CRVAL1'], header_data['CRVAL2'], apply_offsets=False)
    
    print("\nVerification test - calculating CRPIX from CRVAL:")
    print(f"Input CRVAL: ({crval_results['input_target_ra']:.8f}, {crval_results['input_target_dec']:.8f})")
    print(f"Calculated CRPIX: ({crval_results['calculated_crpix_x']:.8f}, {crval_results['calculated_crpix_y']:.8f})")
    print(f"Original CRPIX: ({crval_results['original_crpix_x']:.8f}, {crval_results['original_crpix_y']:.8f})")
    print(f"Difference: ({abs(crval_results['calculated_crpix_x'] - crval_results['original_crpix_x']):.8f}, {abs(crval_results['calculated_crpix_y'] - crval_results['original_crpix_y']):.8f})")
    
    # Test what happens if we don't apply offsets
    no_offset_results = calculate_crpix(header_data, header_data['RA'], header_data['DEC'], apply_offsets=False)
    
    print("\nCalculating CRPIX without applying offsets:")
    print(f"Calculated CRPIX: ({no_offset_results['calculated_crpix_x']:.3f}, {no_offset_results['calculated_crpix_y']:.3f})")
    print(f"Difference from target with offsets: ({abs(no_offset_results['calculated_crpix_x'] - results['calculated_crpix_x']):.3f}, {abs(no_offset_results['calculated_crpix_y'] - results['calculated_crpix_y']):.3f})")

if __name__ == "__main__":
    test_calculate_crpix() 