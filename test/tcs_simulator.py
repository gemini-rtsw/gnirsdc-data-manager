#!/usr/bin/env python3
import os
# Add the following line at the beginning of the file:
os.environ['ASTROPY_USE_SYSTEM_LEAP_SECOND_FILE'] = 'True'
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run
from caproto import ChannelType
import asyncio
from astropy.time import Time

class TCSContext(PVGroup):
    # Right Ascension (RA) in sexagesimal format matching header RA of 153.171733333333 degrees
    track_ra = pvproperty(value="10:12:41.22", dtype=str, name='tc:sad:currentRA')

    # Declination (Dec) in sexagesimal format matching header Dec of 21.9322472222222 degrees
    track_dec = pvproperty(value="+21:55:56.09", dtype=str, name='tc:sad:currentDec')

    # Coordinate frame matching header 'TRKFRAME'
    track_frame = pvproperty(value='FK5', dtype=str, name='tc:sad:sourceATrackFrame')

    # Equinox matching header 'TRKEQUIN' of 2000.0
    track_equinox = pvproperty(value='J2000.0', dtype=str, name='tc:sad:sourceAEpoch')

    # TCS context array (45 elements)
    ast_ctx = pvproperty(
        name='tc:ak:astCtx.VALA',
        value=[0.0] * 45,  # Initialize with 45 zeros
        dtype=ChannelType.DOUBLE,
        max_length=45,
        doc='TCS context array'
    )

    @ast_ctx.startup
    async def ast_ctx(self, instance, async_lib):
        # Initialize with specific values from header
        initial_values = [
            1.73461e+09, -0.0563401, 0.342041, 0.937995, 128042, -1.5844,
            0.000247885, -7.43704e-05, -4.41709e-05, 0.000112754, 1.63787e-06,
            0.345991, 0.339129, 0.94074, 1.461e-06, 4213.4, 275.15, 619.68,
            0.0931, 0.5, 0.0065, 0.000178441, -1.98969e-07, 2.30204, 1.82288e-06,
            6.86096e-13, 5.9705e-16, 6.85791e-13, 2.57942e-16, 1.64437e-07,
            -1.1066e-05, -1.49941, 15.0983, -1.49941, 15.0983, -1.49941,
            15.0983, -0.258293, 15.1023, 0, 1, 0, 0, 0, 1
        ]
        await instance.write(value=initial_values)

    # Observation time in Modified Julian Date (MJD) matching header 'MJD_OBS'
    time_tai = pvproperty(value=60663.5501248462, dtype=float, precision=3, name='tc:sad:djmls')

    # Update camera PV
    camera = pvproperty(value='ShortBlue_G5540', dtype=str, name='tgnirs:sad:cc:cameraPosition')
    
    ra_offset = pvproperty(value=2.82962477863191, dtype=float, name='tc:sad:sourceADiffRA.VAL')
    dec_offset = pvproperty(value=-0.490166004284015, dtype=float, name='tc:sad:sourceADiffDec.VAL')
    pm_ra = pvproperty(value=1.86856864913779E-05, dtype=float, name='tc:sad:sourceAPMRA.VAL')
    pm_dec = pvproperty(value=-0.000774999987160837, dtype=float, name='tc:sad:sourceAPMDec.VAL')
    instr_iaa = pvproperty(value=89.818, dtype=float, name='tc:sad:instrAA.VAL')
    instr_pa = pvproperty(value=87.38, dtype=float, name='tc:sad:instrPA.VAL')

    port = pvproperty(value=3, dtype=int, name='tag:port:nirs')
    ao = pvproperty(value='park-pos.', dtype=str, name='tag:aoName')
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
#    cc31       = pvproperty(value=1, dtype=ChannelType.LONG, name="tgnirs:sad:cc:cameraPosition", doc = "")
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
