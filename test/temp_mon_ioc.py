# lakeshore_ioc.py
import sys
import os
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run
from caproto import ChannelType

# Add the ../src/gnirsDataManager/ directory to the system path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src/gnirsDataManager')))

from lakeshore import Lakeshore325

class LakeshoreIOC(PVGroup):
    temperature = pvproperty(value=0.0, read_only=True, dtype=ChannelType.DOUBLE)
    status = pvproperty(value=" " * 50, read_only=True, dtype=ChannelType.STRING)  # Initialize with a string of spaces

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.lakeshore = Lakeshore325(ip='10.1.2.60', port=3302)
        self.lakeshore.connect()

    @temperature.scan(period=5)  # Scan every 5 seconds
    async def temperature(self, instance, async_lib):
        try:
            temp = self.lakeshore.read_temperature()
            if temp is not None:
                print(f"Temperature read: {temp} K")
                await instance.write(temp)
            else:
                print("Temperature reading returned None")
        except Exception as e:
            print(f"Error reading temperature: {e}")

    @status.scan(period=60)  # Scan every 60 seconds
    async def status(self, instance, async_lib):
        try:
            status = self.lakeshore.check_status()
            if status is not None:
                print(f"Lakeshore Status: {status}")
                await instance.write(status.ljust(50))  # Ensure the status string has a fixed length
            else:
                print("Status reading returned None")
        except Exception as e:
            print(f"Error reading status: {e}")

if __name__ == "__main__":
    ioc_options, run_options = ioc_arg_parser(
        default_prefix='lakeshore:',
        desc="Lakeshore 325 Temperature Controller IOC"
    )
    ioc = LakeshoreIOC(**ioc_options)
    run(ioc.pvdb, **run_options)
