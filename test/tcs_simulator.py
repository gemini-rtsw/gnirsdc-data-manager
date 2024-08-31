#!/usr/bin/env python3
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run
import asyncio
from astropy.time import Time

class TCSContext(PVGroup):
    track_ra = pvproperty(value=231.657670833333, dtype=float, precision=6)
    track_dec = pvproperty(value=-20.8335166666667, dtype=float, precision=7)
    track_frame = pvproperty(value='FK5', dtype=str)
    track_equinox = pvproperty(value=2000.0, dtype=float, precision=1)
    time_tai = pvproperty(value=0.0, dtype=float, precision=3)
    port = pvproperty(value=3, dtype=int)
    camera = pvproperty(value='short', dtype=str)
    ao = pvproperty(value=False, dtype=bool)
    ak_astCtx = pvproperty(value='', dtype=str, name='ak:astCtx')  # Ensure correct PV name

    @time_tai.startup
    async def time_tai(self, instance, async_lib):
        # Update time_tai every second
        while True:
            tai_time = Time.now().tai.mjd
            await instance.write(value=tai_time)
            await async_lib.sleep(1)

if __name__ == '__main__':
    ioc_options, run_options = ioc_arg_parser(
        default_prefix='tcs:',
        desc="TCS Context IOC")
    ioc = TCSContext(**ioc_options)
    run(ioc.pvdb, **run_options)
