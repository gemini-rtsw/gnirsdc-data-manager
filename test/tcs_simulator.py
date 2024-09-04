#!/usr/bin/env python3
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run
import asyncio
from astropy.time import Time

class TCSContext(PVGroup):
    track_ra = pvproperty(value="20:01:14.999", dtype=str, name='tcs:sad:currentRA')
    track_dec = pvproperty(value="+20:50:00.66", dtype=str, name='tcs:sad:currentDec')
    track_frame = pvproperty(value='FK5', dtype=str, name='tcs:sad:sourceATrackFrame')
    track_equinox = pvproperty(value='J2024.67534114438990', dtype=str, name='tcs:sad:sourceAEpoch')
    time_tai = pvproperty(value=0.0, dtype=float, precision=3, name='tcs:sad:djmls')
    camera = pvproperty(value='short', dtype=str, name='tcs:sad:instrPA')
    port = pvproperty(value=3, dtype=int, name='ag:port:nirs')
    ao = pvproperty(value='IN', dtype=str, name='ag:aoName')
    ak_astCtx = pvproperty(value='', dtype=str, name='ak:astCtx')

    @time_tai.startup
    async def time_tai(self, instance, async_lib):
        # Update time_tai every second
        while True:
            tai_time = Time.now().tai.mjd
            await instance.write(value=tai_time)
            await async_lib.sleep(1)

if __name__ == '__main__':
    ioc_options, run_options = ioc_arg_parser(
        default_prefix='',
        desc="TCS Context IOC")
    ioc = TCSContext(**ioc_options)
    run(ioc.pvdb, **run_options)
