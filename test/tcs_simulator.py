#!/usr/bin/env python3
import os
# Add the following line at the beginning of the file:
os.environ['ASTROPY_USE_SYSTEM_LEAP_SECOND_FILE'] = 'True'
from caproto.server import pvproperty, PVGroup, ioc_arg_parser, run
from caproto import ChannelType
import asyncio
from astropy.time import Time

class TCSContext(PVGroup):
    # Right Ascension (RA) in sexagesimal format matching header RA of 67.4006958333333 degrees
    track_ra = pvproperty(value="04:29:36.17", dtype=str, name='tc:sad:currentRA')

    # Declination (Dec) in sexagesimal format matching header Dec of 24.5976555555556 degrees
    track_dec = pvproperty(value="+24:35:51.56", dtype=str, name='tc:sad:currentDec')

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
        # Initialize with specific values
        initial_values = [
            1.73462e+09, 0.310309, 0.422724, 0.851477, 128000, 0.145194, 
            0.000247885, -7.43704e-05, -5.18987e-05, 0.000128232, -7.37791e-06, 
            0.345991, 0.339129, 0.94074, 1.461e-06, 4213.4, 275.34, 619.57, 
            0.1404, 0.5, 0.0065, 0.000178272, -1.98957e-07, 2.47415, 1.82288e-06, 
            3.41779e-13, 1.83958e-16, 3.4177e-13, 1.36354e-16, 3.37543e-10, 
            -5.58104e-07, -0.199816, -0.0834657, -0.199816, -0.0834657, -0.199816, 
            -0.0834657, -0.199816, -0.0834657, 0, 1, 0, 0, 0, 1
        ]
        await instance.write(value=initial_values)

    # Observation time in Modified Julian Date (MJD) matching header 'MJD_OBS'
    time_tai = pvproperty(value=60663.4006663199, dtype=float, precision=3, name='tc:sad:djmls')

    # Update camera PV
    camera = pvproperty(value='ShortBlue_G5540', dtype=str, name='tgnirs:sad:cc:cameraPosition')
    
    # Add instrument position angle PV


    ra_offset = pvproperty(value=2.82962477863191, dtype=float, name='tc:sad:raOffset')
    dec_offset = pvproperty(value=-0.490166004284015, dtype=float, name='tc:sad:decOffset')
    pm_ra = pvproperty(value=1.86856864913779E-05, dtype=float, name='tc:sad:pmRa')
    pm_dec = pvproperty(value=-0.000774999987160837, dtype=float, name='tc:sad:pmDec')
    instr_iaa = pvproperty(value=89.818, dtype=float, name='tc:instrIAA')
    instr_pa = pvproperty(value=70.0, dtype=float, name='tc:instrPA')



    port = pvproperty(value=3, dtype=int, name='tag:port:nirs')
    #ao = pvproperty(value='IN', dtype=str, name='tag:aoName')
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
