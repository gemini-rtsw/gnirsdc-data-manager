#!/usr/bin/env python3
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run
from caproto import ChannelType
import asyncio
from astropy.time import Time

class TCSContext(PVGroup):
    track_ra = pvproperty(value="20:01:14.999", dtype=str, name='tc:sad:currentRA')
    track_dec = pvproperty(value="+20:50:00.66", dtype=str, name='tc:sad:currentDec')
    track_frame = pvproperty(value='FK5', dtype=str, name='tc:sad:sourceATrackFrame')
    track_equinox = pvproperty(value='J2024.67534114438990', dtype=str, name='tc:sad:sourceAEpoch')
    time_tai = pvproperty(value=0.0, dtype=float, precision=3, name='tc:sad:djmls')
    camera = pvproperty(value='short', dtype=str, name='tc:sad:instrPA')
    port = pvproperty(value=3, dtype=int, name='tag:port:nirs')
    ao = pvproperty(value='IN', dtype=str, name='tag:aoName')
    tcs_heartbeat = pvproperty(value=0, dtype=int, name='tc:heartbeat')

    cc1       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:apply.DIR", doc = "")
    cc2       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:apply.VAL", doc = "")
    cc3       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:apply.MESS", doc = "")
    cc4       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:applyC.CLID", doc = "")
    cc5       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:applyC.VAL", doc = "")
    cc6       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:applyC.OMSS", doc = "")
    cc7       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:coverPosCad.B", doc = "")
    cc8       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:fw1PosCad.B", doc = "")
    cc9       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:focusStepsCad.A", doc = "")
    cc10       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:gratingPosCad.E", doc = "")
    cc11       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:xdispPosCad.B", doc = "")
    cc12       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:acqPosCad.B", doc = "")
    cc13       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:focus:focusbest", doc = "")
    cc14       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:gratingPosCad.C", doc = "")
    cc15       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:cameraPosCad.B", doc = "")
    cc16       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:gratingPosCad.A", doc = "")
    cc17       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:gratingPosCad.D", doc = "")
    cc19       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:slitPosCad.B", doc = "")
    cc20       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:deckerPosCad.B", doc = "")
    cc21       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:fw2PosCad.B", doc = "")
    cc22       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:xdispPosition", doc = "")
    cc23       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:focusPosition", doc = "")
    cc24       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:slitPosition", doc = "")
    cc25       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:acqPosition", doc = "")
    cc26       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:coverPosition", doc = "")
    cc27       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:gratingPosition", doc = "")
    cc28       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:cc:gratingPosCad.B", doc = "")
    cc29       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:fw2Position", doc = "")
    cc30       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:fw1Position", doc = "")
    cc31       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:cameraPosition", doc = "")
    cc32       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:deckerPosition", doc = "")
    cc33       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:gratingWvlength.VAL", doc = "")
    cc34       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:deckerEng", doc = "")
    cc35       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:fw2Eng", doc = "")
    cc36       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:gratingEng", doc = "")
    cc37       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:cameraEng", doc = "")
    cc38       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:fw1Eng", doc = "")
    cc39       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:slitEng", doc = "")
    cc40       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:xdispEng", doc = "")
    cc41       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:focusEng", doc = "")
    cc42       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:gratingTilt", doc = "")
    cc43       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:gratingOrder", doc = "")
    cc44       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:name", doc = "")

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
    
    print("PVs to be simulated:")
    for pv_name in ioc.pvdb:
        print(f"  {pv_name}")
    
    run(ioc.pvdb, **run_options)
