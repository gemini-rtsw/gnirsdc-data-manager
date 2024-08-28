from epics import caget, camonitor
import threading
from typing import Dict, Any
import time
import libgnirsioc
import numpy as np

class TCSMonitor:
    def __init__(self):
        self.tcs_pvs = [
            'track_ra', 'track_dec', 'track_frame', 'track_equinox',
            'time_tai', 'port', 'camera', 'ao'
        ]
        self.context: Dict[str, Any] = {}
        self.monitor_thread = None
        self.reconnect_interval = 10  # seconds

    def _process_value(self, value: Any) -> str:
        if isinstance(value, (list, np.ndarray)):
            return ''.join(chr(i) for i in value if i != 0)  # Convert ASCII array to string
        return str(value)  # Convert other types to string

    def on_change(self, pvname: str, value: Any, **kwargs):
        pv_short_name = pvname.split(':')[-1]
        processed_value = self._process_value(value)
        self.context[pv_short_name] = processed_value

    def initialize(self):
        self.connect_and_monitor()
        
        # Start a thread to keep the monitors alive and attempt reconnection
        self.monitor_thread = threading.Thread(target=self._keep_alive_and_reconnect, daemon=True)
        self.monitor_thread.start()

    def connect_and_monitor(self):
        for pv_name in self.tcs_pvs:
            full_pv_name = f'tcs:{pv_name}'
            
            # Get initial value
            value = caget(full_pv_name, timeout=1)
            if value is not None:
                processed_value = self._process_value(value)
                self.context[pv_name] = processed_value
                print(f"Initial value of {full_pv_name}: {processed_value}")
                
                # Set up monitor
                camonitor(full_pv_name, callback=self.on_change)
            else:
                print(f"Could not read initial value of {full_pv_name}. Will try to reconnect later.")

        print("TCS Monitor initialized.")

    def _keep_alive_and_reconnect(self):
        while True:
            time.sleep(self.reconnect_interval)
            for pv_name in self.tcs_pvs:
                full_pv_name = f'tcs:{pv_name}'
                if pv_name not in self.context:
                    value = caget(full_pv_name, timeout=1)
                    if value is not None:
                        processed_value = self._process_value(value)
                        self.context[pv_name] = processed_value
                        print(f"Reconnected and got initial value of {full_pv_name}: {processed_value}")
                        camonitor(full_pv_name, callback=self.on_change)

    def get_context(self) -> libgnirsioc.TCSContext:
        context = libgnirsioc.TCSContext()
        for key, value in self.context.items():
            setattr(context, key, value)
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
