import caproto
from caproto.server import pvproperty, SubGroup, PVGroup, ioc_arg_parser, run
from pygeminirec.applyrecord import ApplyRecord
from pygeminirec.cadrecord import CADRecord
from pygeminirec.carrecord import CARRecord
from pygeminirec.base import CADDirective

import asyncio
from concurrent.futures import ThreadPoolExecutor

from time import sleep
from typing import Any, Union

from multiprocessing import Process, Queue

import time

import os, shutil, glob
from datetime import datetime

from libgnirsioc import controllerInterface
from libgnirsioc import controllerInterfaceDebug
from libgnirsioc import setGlobalDebug

from fits_header_definitions import generate_new_filename


from lakeshore import Lakeshore325

from gnirsutil import config, config_mode, DEBUG_MODE

TEMP_CON_IP         = config[config_mode].get('TEMP_CON_IP')
TEMP_CON_PORT       = config[config_mode].getint('TEMP_CON_PORT')
INTERLOCK_TEMP      = config[config_mode].getfloat('INTERLOCK_TEMP')

print(f"TEMP_CON_IP: {TEMP_CON_IP}, TEMP_CON_PORT: {TEMP_CON_PORT}, INTERLOCK_TEMP: {INTERLOCK_TEMP}")


# Function to get the current timestamp
def get_current_timestamp():
    now = datetime.now()
    milliseconds = int(time.time() * 1000) % 1000
    return now.strftime("%Y%m%d%H%M%S") + f"{milliseconds:03d}"


class GnirsCAD(CADRecord):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)  # Call parent constructor if it does anything
        self.giapi = self.parent.parent.GIAPIInterface
        self.logMessage = self.parent.parent.logMessage
        self.p = self.parent

    @property
    def controller(self):
        return self.parent.sdsuController

    @controller.setter
    def controller(self, value):
        self.parent.sdsuController = value


class InitCAD(GnirsCAD):
    async def start(self):
        print("InitCAD start")

        await self.logMessage("InitCAD start")
        await self.MESS.write("Init successfull")
        return True


class BiasCAD(GnirsCAD):
    async def start(self):
        if (self.controller == None and DEBUG_MODE == False):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            print("BiasCAD start")
            
            biasVal = self.parent.detBias.value

            if (biasVal == -3.6):
                self.controller.biasLow()
                await self.logMessage("Bias set to shallow: -3.6")
                await self.MESS.write("Set Bias successfull")
                return True
            elif (biasVal == -3.2):
                self.controller.biasHigh()
                await self.logMessage("Bias set to deep: -3.2")
                await self.MESS.write("Set Bias successfull")
                return True

            else:
                await self.logMessage("Invalid bias voltage value. Leaving bias at: " + str(biasVal))
                await self.MESS.write("Set Bias failed")
                return False

                

class TDLCAD(GnirsCAD):
    async def start(self):
        if (self.controller == None and DEBUG_MODE == False):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else: 
            result = self.controller.testDataLink()
            await self.logMessage(f"TDL: {result}")
            await self.MESS.write("Set Bias successfull")
            return True


class InitSDSUCAD(GnirsCAD):

    async def start(self):

        try:
            '''
            # deallocate controller just in case this is an additional init
            self.controller = None

            if (DEBUG_MODE):
                await self.logMessage("DEBUG MODE ENABLED")
                self.controller = controllerInterfaceDebug()

                await self.logMessage("SDSU Debug Mode initialization successful")
                await self.MESS.write("Controller Init Successfull")
                return True
            else:
                await self.logMessage("SDSU Initializing")

                firmware_full_path = os.path.join(os.getcwd(), "firmware/AladdinIII_SDSU_Firmware.lod")

                print(f"LOD Path: {firmware_full_path}")
                # Normalize the path to resolve any symbolic links, ".." or "." etc.
                firmware_full_path = os.path.normpath(firmware_full_path)

                self.controller = controllerInterface("/readout_data", firmware_full_path)

                self.controller.setAladdinIII(True)

                result = self.controller.testDataLink()

                if result:
                    if self.controller.init():
                        await self.logMessage("SDSU Initialization successful")
                        await self.MESS.write("SDSU Initialization successful")
                        await self.p.sdsuState.write("INITIALIZED")
                        return True
                        '''
                     # deallocate controller just in case this is an additional init
            self.controller = None

            await self.logMessage("SDSU Initializing")

            firmware_full_path = os.path.join(os.getcwd(), "firmware/AladdinIII_SDSU_Firmware.lod")

            print(f"LOD Path: {firmware_full_path}")
            # Normalize the path to resolve any symbolic links, ".." or "." etc.
            firmware_full_path = os.path.normpath(firmware_full_path)

            setGlobalDebug(DEBUG_MODE)
            self.controller = controllerInterface("/readout_data", firmware_full_path)

            self.controller.setAladdinIII(True)

            result = self.controller.testDataLink()

            if result:
                if self.controller.init():
                    await self.logMessage("SDSU Initialization successful")
                    await self.MESS.write("SDSU Initialization successful")
                    await self.p.sdsuState.write("INITIALIZED")
                    return True
                    

        except Exception as e:
            error_message = str(e)
            await self.logMessage(f"An exception occurred: {error_message}")
            await self.MESS.write("Controller Init Error")
            self.controller = None
            return False
        
        await self.logMessage("SDSU Initialization failed")
        await self.MESS.write("SDSU Initialization failed")
        self.controller = None
        return False







class DCConfigCAD(GnirsCAD):
    async def start(self):
        if (self.controller == None and DEBUG_MODE == False):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, self.p.coaddsVAL.value, self.dropReadoutsNum.value, self.p.observeA.value)
            await self.MESS.write("Configuration Set Successfully")
            return True


class AbortCAD(GnirsCAD):
    async def start(self):
        if (self.controller == None):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            self.controller.abortExposure()
            await self.logMessage(f"Aborting Exposure")
            await self.MESS.write("Abort Successful")
            return True


class ObserveCAD(GnirsCAD):

    async def start(self):
        if (self.controller == None):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")

            return False
        elif (self.p.temperature.value > INTERLOCK_TEMP):

            await self.logMessage(f"Detector not at temperature")
            await self.MESS.write("Detector not at temperature")

            return False
        else:

            if (int(self.p.rdout.value) == 0):

                if self.p.sequence.value < 1:
                    await self.p.sequence.write(1)

                for i in range(self.p.sequence.value, 0, -1):   # reverse and end at i = 1
                    # Add the timestamp to the observeA value if labelTimeStamp is greater than 0
                    if self.p.labelTimeStamp.value > 0:
                        timestamp = get_current_timestamp()
                        await self.p.observeA.write(f"{timestamp}-{i}")

                    # Add fits extension if not going to archive
                    if self.p.parent.archive_fits.value == 0:
                        if not self.p.observeA.value.endswith('.fits'):
                            await self.p.observeA.write(f"{self.p.observeA.value}.fits")

                    #begin readout
                    self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, int(self.p.coaddsVAL.value), int(self.p.dropReadoutsNum.value), self.p.observeA.value)

                    await self.p.rdout.write(1)


                    # Run countdown_timer in a separate thread to prevent blocking
                    exposure_delay = self.controller.getExposureDelay(self.p.exposureTime.value, self.p.obsSetupD.value, self.p.obsSetupC.value)
                    asyncio.create_task(self.countdown_timer(self.p.exposureTime.value))

                    await self.start_async_exposure()
                

                    await self.p.sequenceLeft.write(i) # keep track of the remaining exposures
                                                       # end at 1 so it will do a single exposure if sequence is not manually set

                # and turn off raw data
                await self.p.parent.include_eng.write(0)
                # set write to fits archive by default don't want a test write to affect a seqexec readout
                await self.p.parent.archive_fits.write(1)
                # Remove the .fits extension after readout is done
                if self.p.observeA.value.endswith('.fits'):
                    await self.p.observeA.write(self.p.observeA.value[:-5])


                await self.MESS.write("Observe CAD Completed Successfully")
                return True
        
            else:
                await self.logMessage(f'Readout in progress')
                await self.MESS.write("Observe Failure - Readout in Progress")
                return False
            
            


    async def start_async_exposure(self):

        await self.logMessage(f'{self.prefix} ObserveCAD start')
        print(f'{self.prefix} ObserveCAD start')

        # if sending to archive let GDS know
        if (self.p.parent.archive_fits.value):
            #await self.logMessage(f'DataLabel: {self.giapi.dataLabel}')
            await self.logMessage(f'DataLabel: {self.p.observeA.value}')
        
            await self.logMessage(f'sending observe prep to GMP')

            self.giapi.observePrep(self.p.observeA.value)
            self.giapi.observeStartAcq(self.p.observeA.value)
            self.giapi.observeEndAcq(self.p.observeA.value)

            await self.logMessage(f'sending start readout to GMP')

            self.giapi.observeStartReadout(self.p.observeA.value)

            await self.logMessage(f'sending start readout to SDSU')

        # readout SDSU
        self.controller.startExposure(self.p.detectorTemp1.value, self.p.detectorTemp1.value, self.p.parent.include_eng.value)	

        await self.logMessage(f'SDSU readout started')

        while self.controller.getReadingOut(): 
            await asyncio.sleep(0.01)

        await self.logMessage(f'SDSU readout complete')

        # if sending to archive let GDS know
        if (self.p.parent.archive_fits.value):
            self.giapi.observeEndReadout(self.p.observeA.value)

            await self.logMessage(f'GDS writing fits')

            self.giapi.observeStartWrite(self.p.observeA.value)

            self.giapi.observeEndWrite(self.p.observeA.value)

        #complete readout
        await self.logMessage(f'ObserveCAD end')
                                         
        # set write to fits archive by default don't want a test write to affect a seqexec readout
        #await self.p.parent.archive_fits.write(1)
        # and turn off raw data
        #await self.p.parent.include_eng.write(0)


        await self.p.rdout.write(0)





    async def countdown_timer(self, total_time):

        if total_time <= 0.2: # about minimum readout time 
            total_time = 0.2

        coadds_completed = 0

        while self.p.rdout.value: # keep looping if rdout is true, if time is up and rdout true then we are doing coadds 

            start_time = time.time()

            while True:
                current_time = time.time()
                elapsed_time = current_time - start_time
                remaining_time = total_time - elapsed_time

                await self.p.timeLeft.write(str(max(remaining_time, 0)))
                await self.p.obsProgress.write(100 - (max(remaining_time, 0) / total_time) * 100)

                await asyncio.sleep(0.05)  

                if remaining_time <= 0 or self.p.rdout.value <= 0:
                    break

            coadds_completed += 1
            await self.p.coaddProgress.write(100 * coadds_completed / self.p.coaddsVAL.value)





async def run_exposure_async(detector_temp, include_eng):
    # Create a process to run the exposure start function
    process = Process(target=start_exposure_process, args=(detector_temp, include_eng))
    process.start()

    # Wait asynchronously for the process to complete
    while process.is_alive():
        await asyncio.sleep(0.1)  # Adjust the sleep time as needed

    process.join()  # Ensure the process is cleaned up


class StopCAD(GnirsCAD):
    async def start(self):
        print("StopCAD start")
        await self.MESS.write("StopCAD start")
        return True


class GnirsCADCARController(PVGroup):


    # Initialize CAR and CAD commands as attributes
    applyC = SubGroup(CARRecord, prefix='dc:applyC.')
    apply = SubGroup(ApplyRecord, prefix='dc:apply.')        
    TDL = SubGroup(TDLCAD, prefix='dc:TDL.')
    bias = SubGroup(BiasCAD, prefix='dc:bias.')
    init = SubGroup(InitCAD, prefix='dc:init.')
    initSDSU = SubGroup(InitSDSUCAD, prefix='dc:initSDSU.')
    dcconfig = SubGroup(DCConfigCAD, prefix='dc:dcconfig.')
    endObserve = SubGroup(AbortCAD, prefix='dc:endObserve.')
    abort = SubGroup(AbortCAD, prefix='dc:abort.')
    stop = SubGroup(AbortCAD, prefix='dc:stop.')
    observe = SubGroup(ObserveCAD, prefix='dc:observe.')
    observeC = SubGroup(CARRecord, prefix='dc:observeC.')


    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        print(f"Debug mode: {DEBUG_MODE}")


        self.lakeshore = Lakeshore325(TEMP_CON_IP, TEMP_CON_PORT)
        self.lakeshore.connect()

        self.sdsuController = None

        # CAD commands connect to top level CAR record
#        for cmd in [self.dcconfig, self.endObserve, self.abort, self.observe, self.stop]:
#            cmd.car_record = self.applyC

        # Apply command connects to CAD/CAR records
        self.apply.cars.records = [self.applyC]
        #self.apply.cads.records = [self.dcconfig, self.observe]


        # some kind of order bug. observe must go first or seqexec will error ?? 
        self.apply.cads.records = [self.observe, self.dcconfig, self.endObserve, self.abort, self.observe, self.stop, self.init, self.initSDSU, self.TDL, self.bias]

        # Observe has it's own CAR
        self.observe.cars.records = [self.observeC]
        self.observeC.cars.records = [self.applyC]


    #------ DC configuration values --------

    #------ fowlers - lnr -------------------
    obsSetupD      = pvproperty(value=1, dtype=caproto.ChannelType.STRING, name="dc:obsSetup.D", doc = "")
    @obsSetupD.putter
    async def obsSetupD(self, instance, value):
        if (self.lnrNum.value != int(value)):
            await self.lnrNum.write(int(value))


    lnrNum          = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:lnrNum", doc = "Low Noise Reads") 
    @lnrNum.putter
    async def lnrNum(self, instance, value):
        await self.parent.logMessage(f"LNR: {value}")
    #------ fowlers - lnr -------------------


    #------ readouts to drop -------------------
    dropReadoutsNum         = pvproperty(value=0, dtype=caproto.ChannelType.INT, name="dc:dropReadoutsNum", doc = "Drop readouts") 
    @dropReadoutsNum.putter
    async def dropReadoutsNum(self, instance, value):
        await self.parent.logMessage(f"Drop Readouts: {value}")
    #------ readouts to drop -------------------


    #------ read up the ramp -------------------
    readUpTheRamp         = pvproperty(value=0, dtype=caproto.ChannelType.INT, name="dc:readUpTheRamp", doc = "Read Up The Ramp Mode Bool") 
    @readUpTheRamp.putter
    async def readUpTheRamp(self, instance, value):
        await self.parent.logMessage(f"Read Up the Ramp Mode: {value > 0}")
    #------ read up the ramp -------------------


    #-------------- exposureTime -------------------
    exposureTime    = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:integTime.VAL", doc = "Exposure Time") 
    @exposureTime.putter
    async def exposureTime(self, instance, value):
        await self.parent.logMessage(f"Exposure Time: {value}")
    #-------------- exposureTime -------------------



    #-------------- digitalAvgs -------------------
    obsSetupC      = pvproperty(value=1, dtype=caproto.ChannelType.STRING, name="dc:obsSetup.C", doc = "")
    @obsSetupC.putter
    async def obsSetupC(self, instance, value):
        if (self.digitalAvgs.value != int(value)):
            await self.digitalAvgs.write(int(value))

    digitalAvgs     = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:digitalAvgs", doc = "Digital Averages") 
    @digitalAvgs.putter
    async def digitalAvgs(self, instance, value):
        await self.parent.logMessage(f"ADC: {value}")
    #-------------- digitalAvgs -------------------




    #-------------- coadds -------------------
    coaddsVAL      = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:coadds.VAL", doc = "")
    @coaddsVAL.putter
    async def coaddsVAL(self, instance, value):
        await self.parent.logMessage(f"Coadds: {value}")
    #-------------- coadds -------------------



    #-------------- Temp Monitor -------------------
    temperature = pvproperty(value=0.0, read_only=True, dtype=caproto.ChannelType.DOUBLE, name="dc:temperature")

    @temperature.startup
    async def temperature(self, instance, async_lib):
        await self.parent.logMessage(f"Temperature Interlock: {INTERLOCK_TEMP}")

    @temperature.scan(period=5)  # Scan every 5 seconds
    async def temperature(self, instance, async_lib):
        try:
            temp = self.lakeshore.read_temperature()
            if temp is not None:
                #print(f"Temperature read: {temp} K")
                await instance.write(temp)
            else:
                print("Temperature reading returned None")
        except Exception as e:
            print(f"Error reading temperature: {e}")

    temperature_status  = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:temperature_status")    
    @temperature_status.scan(period=60)  # Scan every 60 seconds
    async def temperature_status(self, instance, async_lib):
        try:
            status = self.lakeshore.check_status()
            if status is not None:
                #print(f"Lakeshore Status: {status}")
                status_string = status[:40].ljust(40)
                await instance.write(status_string)
            else:
                print("Status reading returned None")
        except Exception as e:
            print(f"Error reading status: {e}")
    #-------------- Temp Monitor -------------------



    #------ DC configuration values --------
    sequence        = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:sequence", doc = "Sequence Count") 
    @sequence.putter
    async def sequence(self, instance, value):
        await self.sequenceLeft.write(value)


    sequenceLeft    = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:sequenceLeft", doc = "Exposures left to readout")

    sdsuState       = pvproperty(value='NOT INITIALIZED', dtype=caproto.ChannelType.STRING, name="dc:sdsuState", doc = "SDSU Controller State") 


    achvdBias       = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:achvdBias.VAL", doc = "Achieved Detector Bias") 


    detBias         = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:detBias", doc = "Detector Bias") 
    wcs             = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="dc:wcs", doc = "WCS file") 



    dataLabel       = pvproperty(value='GN20231011S1800', dtype=caproto.ChannelType.STRING, name="dc:dataLabel", doc = "Data Label") 


    detectorTemp1   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp1", doc = "Detector Temperature 1")
    detectorTemp2   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp2", doc = "Detector Temperature 2")

    timeLeft        = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="sad:dc:timeLeft", doc = "Exposure time left") 
    obsProgress     = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsProgress", doc = "Exposure percent complete") 
    coaddProgress   = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:coaddProgress", doc = "Coadd percent complete") 


    setWcsA        = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:setWcs.A", doc = "")


    arSetupH       = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:arSetup.H", doc = "")
    detIDVAL       = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="sad:dc:detID.VAL", doc = "")
    detTypeVAL     = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="sad:dc:detType.VAL", doc = "")
    obsepoch       = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsepoch", doc = "")
    setWcsVALA     = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:setWcs.VALA", doc = "")

    obsSetupVALC   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name=  "dc:obsSetup.VALC", doc = "")
    obsSetupVALD   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name=  "dc:obsSetup.VALD", doc = "")
    obsSetupVALE   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name=  "dc:obsSetup.VALE", doc = "")

    dhsConnected   = pvproperty(value=1, dtype=caproto.ChannelType.LONG, name=  "sad:dc:dhsConnected", doc = "")
    minIntVAL      = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:minInt.VAL", doc = "")
    C1Tmp          = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:C1Tmp", doc = "")



    prep           = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="sad:dc:prep", doc = "")
    acq            = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="sad:dc:acq", doc = "")
    rdout           = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="sad:dc:rdout", doc = "Reading out") 

    labelTimeStamp = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:labelTimeStamp", doc = "add timestamp to file label") 


    activate       = pvproperty(value=1, dtype=caproto.ChannelType.ENUM, enum_strings=['Deactivate', 'Activate'], name="dc:activate", doc = "")



    observeA       = pvproperty(value="eng_readout", dtype=caproto.ChannelType.STRING, name="dc:observe.A", doc = "")

    @observeA.putter
    async def observeA(self, instance, value):
        print(f"Value changed to: {value}")

        ## obsSetupA has a forward link to observeCAD to mark it so it will process
        # seqexec never sets observe CAD DIR to MARK so it is done manually here

        await self.observe.DIR.write(CADDirective.MARK)

        #await self.labelTimeStamp.write(0) # turn off time stamps - seqexec will handle the name
        await self.dataLabel.write(value)


