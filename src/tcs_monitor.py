import logging
from epics import PV
import threading
from typing import Dict, Any
import time
import libgnirsioc
import numpy as np

# Import custom log levels
from logging_config import IRDC_DEBUG, IRDC_MAX_DEBUG

class TCSMonitor:
    def __init__(self):
        self.tcs_pvs = [
            'tcs:sad:currentRA',        # 'track_ra'
            'tcs:sad:currentDec',       # 'track_dec'
            'tcs:sad:sourceATrackFrame',# 'track_frame'
            'tcs:sad:sourceAEpoch', # 'track_equinox'
            'tcs:sad:djmls',            # 'time_tai'
            'tcs:sad:instrPA',          # 'camera'
            'ag:port:nirs',             # 'port'
            'ag:aoName'                 # 'ao' 
        ]
        self.context: Dict[str, Any] = {}
        self.pv_objects: Dict[str, PV] = {}
        self.monitor_thread = None
        self.logger = logging.getLogger(__name__)

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

    def get_context(self) -> libgnirsioc.TCSContext:
        # Create a new TCSContext object as defined in libgnirsioc header
        context = libgnirsioc.TCSContext()

        # Mapping of PV names to TCSContext attributes
        # These attribute names are defined in the libgnirsioc header
        mapping = {
            'currentRA': 'track_ra',        # Right Ascension
            'currentDec': 'track_dec',      # Declination
            'sourceATrackFrame': 'track_frame',  # Coordinate frame
            'sourceAEpoch': 'track_equinox',  # Equinox
            'djmls': 'time_tai',            # Time in TAI
            'nirs': 'port',                 # Instrument port
            'instrPA': 'camera',            # Camera position angle
            'aoName': 'ao'                  # Adaptive optics mode
        }

        # Populate the TCSContext object with values from self.context
        for pv_name, context_name in mapping.items():
            if pv_name in self.context:
                setattr(context, context_name, self.context[pv_name])

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
