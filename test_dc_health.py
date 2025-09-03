#!/usr/bin/env python3
"""
Simple test script to verify the dc:dcHealth channel functionality
"""

import time
import sys
import os

# Add the src directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from caproto.sync.client import read, write

def test_dc_health_channel():
    """Test the dc:dcHealth channel"""
    
    # Use the default prefix from config
    prefix = "nirs"  # Default prefix
    health_pv = f"{prefix}:dc:dcHealth"
    tcs_pv = f"{prefix}:tcs_connection"
    gmp_pv = f"{prefix}:gmp_status"
    
    print("Testing dc:dcHealth channel...")
    print(f"Health PV: {health_pv}")
    print(f"TCS PV: {tcs_pv}")
    print(f"GMP PV: {gmp_pv}")
    print("-" * 50)
    
    try:
        # Read the health status
        health_status = read(health_pv)
        print(f"DC Health Status: {health_status.data[0]}")
        
        # Read related status indicators
        try:
            tcs_status = read(tcs_pv)
            print(f"TCS Connection: {tcs_status.data[0]}")
        except Exception as e:
            print(f"TCS Connection: ERROR - {e}")
            
        try:
            gmp_status = read(gmp_pv)
            print(f"GMP Status: {gmp_status.data[0]}")
        except Exception as e:
            print(f"GMP Status: ERROR - {e}")
            
    except Exception as e:
        print(f"Error reading dc:dcHealth: {e}")
        print("Make sure the GNIRS Data Manager IOC is running")
        return False
        
    return True

if __name__ == "__main__":
    print("DC Health Channel Test")
    print("=" * 50)
    
    success = test_dc_health_channel()
    
    if success:
        print("\nTest completed successfully!")
        print("The dc:dcHealth channel is responding.")
        print("\nTo monitor continuously, use:")
        print("  camonitor nirs:dc:dcHealth")
        print("  camonitor nirs:tcs_connection")  
        print("  camonitor nirs:gmp_status")
    else:
        print("\nTest failed. Check that the IOC is running.")
        sys.exit(1)
