# main.py
import sys
import os
import time

# Add the parent directory to the system path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

from lakeshore import Lakeshore325

if __name__ == "__main__":
    lakeshore = Lakeshore325(ip='10.1.2.60', port=3302)
    lakeshore.connect()

    temperature = lakeshore.read_temperature()
    if temperature is not None:
        print(f"Current Temperature: {temperature} K")
    else:
        print("Could not read temperature.")

    # Adding a short delay before checking status to ensure command completion
    time.sleep(0.5)

    status = lakeshore.check_status()
    if status:
        print(f"Lakeshore Status: {status}")
    else:
        print("Could not check status.")

    lakeshore.disconnect()
