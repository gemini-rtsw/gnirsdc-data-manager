# lakeshore_ioc.py
import sys
import os
import caproto
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run

# Add the ../src/gnirsDataManager/ directory to the system path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src/gnirsDataManager')))

from lakeshore import Lakeshore325

lakeshore = Lakeshore325(ip='10.1.2.60', port=3302)

class LakeshoreIOC(PVGroup):
    temperature = pvproperty(value=0.0, read_only=True)

    @temperature.scan(period=5)  # Scan every 5 seconds
    async def temperature(self, instance, async_lib):
        try:
            lakeshore.connect()
            temp = lakeshore.read_temperature()
            lakeshore.disconnect()
            if temp is not None:
                await instance.write(temp)
            else:
                print("Temperature reading returned None")
        except Exception as e:
            print(f"Error reading temperature: {e}")
            if lakeshore.sock:
                lakeshore.disconnect()

if __name__ == "__main__":
    ioc_options, run_options = ioc_arg_parser(
        default_prefix='lakeshore:',
        desc="Lakeshore 325 Temperature Controller IOC"
    )
    ioc = LakeshoreIOC(**ioc_options)
    run(ioc.pvdb, **run_options)
