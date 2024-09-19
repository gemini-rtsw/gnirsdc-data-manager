import logging
from epics import PV
import threading
from typing import Dict, Any
import time
import libgnirsioc
import numpy as np
import socket
import struct

# Import custom log levels and DEBUG_MODE
from logging_config import IRDC_DEBUG, IRDC_MAX_DEBUG
from gnirsutil import DEBUG_MODE

class TCSMonitor:
    def __init__(self):
        # Determine the prefixes based on DEBUG_MODE
        tcs_prefix = 'tc:' if DEBUG_MODE else 'tcs:'
        ag_prefix = 'tag:' if DEBUG_MODE else 'ag:'

        self.tcs_pvs = [
            f'{tcs_prefix}sad:currentRA',         # 'track_ra'
            f'{tcs_prefix}sad:currentDec',        # 'track_dec'
            f'{tcs_prefix}sad:sourceATrackFrame', # 'track_frame'
            f'{tcs_prefix}sad:sourceAEpoch',      # 'track_equinox'
            # Removed 'sad:djmls' as we will use NTP time
            f'{tcs_prefix}sad:instrPA',           # 'camera'
            f'{ag_prefix}port:nirs',              # 'port'
            f'{ag_prefix}aoName'                  # 'ao' 
        ]
        self.context: Dict[str, Any] = {}
        self.pv_objects: Dict[str, PV] = {}
        self.monitor_thread = None
        self.logger = logging.getLogger(__name__)

        # Log the PV names at IRDC_DEBUG level
        self.logger.log(IRDC_DEBUG, "PVs to be monitored:")
        for pv in self.tcs_pvs:
            self.logger.log(IRDC_DEBUG, f"  {pv}")

    def _process_value(self, value: Any) -> str:
        if isinstance(value, (list, np.ndarray)):
            return ''.join(chr(i) for i in value if i != 0)  # Convert ASCII array to string
        return str(value)  # Convert other types to string

    def on_change(self, pvname: str, value: Any, **kwargs):
        pv_short_name = pvname.split(':')[-1]
        self.context[pv_short_name] = self._process_value(value)

    def initialize(self):
        self.monitor_thread = threading.Thread(target=self._monitor_pvs, daemon=True)
        self.monitor_thread.start()
        self.logger.irdc_debug("TCS Monitor thread started.")

    def _monitor_pvs(self):
        for full_pv_name in self.tcs_pvs:
            pv = PV(full_pv_name, callback=self.on_change, auto_monitor=True)
            self.pv_objects[full_pv_name] = pv

        while True:
            for full_pv_name, pv in self.pv_objects.items():
                if not pv.connected:
                    self.logger.warning(f"PV {full_pv_name} is not connected. Attempting to reconnect.")
                    pv.connect(timeout=0.1)  # Non-blocking connect attempt
                elif pv.value is not None:
                    pv_short_name = full_pv_name.split(':')[-1]
                    self.context[pv_short_name] = self._process_value(pv.value)
            time.sleep(1)  # Check connections every second

    def get_ntp_time(self) -> str:
        if DEBUG_MODE:
            # Return hardcoded MJD for the debug literal time
            return "60519.666666666666"  # MJD for the debug time

        NTP_SERVER = 'pool.ntp.org'
        NTP_PORT = 123
        NTP_DELTA = 2208988800  # NTP timestamp delta between 1900 and 1970

        try:
            client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            client.settimeout(5)
            # NTP packet is 48 bytes
            msg = b'\x1b' + 47 * b'\0'
            client.sendto(msg, (NTP_SERVER, NTP_PORT))
            data, _ = client.recvfrom(1024)
            if data:
                t = struct.unpack('!12I', data)[10]
                t -= NTP_DELTA
                # Get UTC time in seconds since epoch
                ntp_time = time.gmtime(t)
                ntp_time_str = time.strftime('%Y-%m-%d %H:%M:%S', ntp_time)

                # Convert to MJD using astropy
                mjd = Time(ntp_time_str, format='iso', scale='utc').mjd

                # Return MJD as a string
                return str(mjd)
        except Exception as e:
            self.logger.error(f"Failed to get NTP time: {e}")
            # Fallback to local time in UTC and convert to MJD
            fallback_time = time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())
            mjd = Time(fallback_time, format='iso', scale='utc').mjd
            return str(mjd)

    def get_context(self) -> libgnirsioc.TCSContext:
        # Create a new TCSContext object as defined in libgnirsioc header
        context = libgnirsioc.TCSContext()

        # Mapping of PV names to TCSContext attributes
        # These attribute names are defined in the libgnirsioc header
        mapping = {
            'currentRA': 'track_ra',         # Right Ascension
            'currentDec': 'track_dec',       # Declination
            'sourceATrackFrame': 'track_frame',  # Coordinate frame
            'sourceAEpoch': 'track_equinox',  # Equinox
            'instrPA': 'camera',             # Camera position angle
            'nirs': 'port',                   # Instrument port
            'aoName': 'ao'                    # Adaptive optics mode
        }

        # Populate the TCSContext object with values from self.context
        for pv_name, context_name in mapping.items():
            if pv_name in self.context:
                setattr(context, context_name, self.context[pv_name])

        # Set the NTP time
        context.time = self.get_ntp_time()

        return context

# Example usage
if __name__ == '__main__':
    tcs = TCSMonitor()
    tcs.initialize()

    try:
        while True:
            context = tcs.get_context()
            print(f"Current context: {context}")
            time.sleep(5)
    except KeyboardInterrupt:
        print("Monitor stopped.")
