import logging
from epics import PV, caput
import threading
from typing import Dict, Any
import time
import libgnirsioc
import numpy as np
import socket
import struct
from astropy.time import Time
import subprocess

# Import custom log levels and use the shared config system
from logging_config import IRDC_DEBUG, IRDC_MAX_DEBUG
from gnirsutil import config, config_mode

class TCSMonitor:
    def __init__(self):
        # Use the same config and config_mode as the rest of the system
        # Get the prefixes from the current config section
        tcs_prefix = config[config_mode].get('TCS_PREFIX', 'tcs:')
        ag_prefix = config[config_mode].get('AG_PREFIX', 'ag:')
        cc_prefix = config[config_mode].get('CC_PREFIX', 'nirs:')

        self.tcs_pvs = [
            f'{tcs_prefix}sad:currentRA',         # 'track_ra'
            f'{tcs_prefix}sad:currentDec',        # 'track_dec'
            f'{tcs_prefix}sad:sourceATrackFrame', # 'track_frame'
            f'{tcs_prefix}sad:sourceAEpoch',      # 'track_equinox'
            f'{tcs_prefix}sad:sourceADiffRA.VAL', # 'ra_offset'
            f'{tcs_prefix}sad:sourceADiffDec.VAL', # 'dec_offset'
            f'{tcs_prefix}sad:sourceAPMRA.VAL',   # 'pm_ra'
            f'{tcs_prefix}sad:sourceAPMDec.VAL',  # 'pm_dec'
            f'{tcs_prefix}sad:instrAA.VAL',       # 'inst_iaa'
            f'{tcs_prefix}sad:instrPA.VAL',       # 'inst_pa'
            f'{cc_prefix}sad:cc:cameraPosition',  # 'camera'
            f'{ag_prefix}port:nirs',              # 'port'
            f'{ag_prefix}aoName'                  # 'ao' 
        ]
        self.context: Dict[str, Any] = {}
        self.pv_objects: Dict[str, PV] = {}
        self.monitor_thread = None
        self.connection_monitor_thread = None
        self.logger = logging.getLogger(__name__)
        
        # Get the status reporting PV name based on current config
        top_name = config[config_mode].get('DEFAULT_PREFIX', 'nirs')
        self.status_pv = f'{top_name}:subsystem_connections'

        # Log the PV names at IRDC_DEBUG level
        self.logger.log(IRDC_DEBUG, "PVs to be monitored:")
        for pv in self.tcs_pvs:
            self.logger.log(IRDC_DEBUG, f"  {pv}")
        self.logger.log(IRDC_DEBUG, f"Status reporting PV: {self.status_pv}")

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
        
        self.connection_monitor_thread = threading.Thread(target=self._monitor_connections, daemon=True)
        self.connection_monitor_thread.start()
        
        self.logger.log(IRDC_DEBUG, "TCS Monitor threads started.")

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
    
    def _monitor_connections(self):
        """Monitor connection status of all TCS PVs and report overall status"""
        while True:
            try:
                connected_count = 0
                total_count = len(self.pv_objects)
                
                for full_pv_name, pv in self.pv_objects.items():
                    if pv.connected:
                        connected_count += 1
                
                # Calculate connection percentage
                if total_count > 0:
                    connection_percentage = (connected_count / total_count) * 100
                    
                    # Determine status string
                    if connection_percentage >= 80:
                        status = "CONNECTED"
                    elif connection_percentage >= 50:
                        status = "PARTIAL"
                    else:
                        status = "DISCONNECTED"
                    
                    # Update the status PV
                    try:
                        caput(self.status_pv, status, wait=False)
                        self.logger.log(IRDC_DEBUG, f"Subsystem status: {status} ({connected_count}/{total_count} PVs connected)")
                    except Exception as e:
                        self.logger.error(f"Failed to update status PV {self.status_pv}: {str(e)}")
                else:
                    caput(self.status_pv, "NO_PVS", wait=False)
                    
            except Exception as e:
                self.logger.error(f"Error in connection monitoring: {str(e)}")
            
            time.sleep(5)  # Update status every 5 seconds

    def get_ntp_time(self) -> str:

        # Use system time, which should be synced with NTP
        current_time = time.time()
        mjd = Time(current_time, format='unix', scale='utc').mjd
        return str(mjd)

    def get_context(self) -> libgnirsioc.TCSContext:
        # Create a new TCSContext object as defined in libgnirsioc header
        context = libgnirsioc.TCSContext()

        # Mapping of PV names to TCSContext attributes
        # These attribute names are defined in the libgnirsioc header
        mapping = {
            'currentRA': 'track_ra',
            'currentDec': 'track_dec',
            'sourceATrackFrame': 'track_frame',
            'sourceAEpoch': 'track_equinox',
            'sourceADiffRA.VAL': 'ra_offset',
            'sourceADiffDec.VAL': 'dec_offset',
            'sourceAPMRA.VAL': 'pm_ra',
            'sourceAPMDec.VAL': 'pm_dec',
            'instrAA.VAL': 'inst_iaa',
            'instrPA.VAL': 'inst_pa',
            'cameraPosition': 'camera',
            'nirs': 'port',
            'aoName': 'ao'
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
