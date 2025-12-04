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
import hashlib

from tcs_monitor import TCSMonitor

import time

import os, shutil, glob
from datetime import datetime

from libgnirsioc import controllerInterface
from libgnirsioc import controllerInterfaceDebug
from libgnirsioc import setGlobalDebug

from fits_header_definitions import generate_new_filename

from wcs_utils import choose_file  

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
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            print("BiasCAD start")
            try:
                if self.parent.arSetupH.value == "0.3":  # Seqexec uses 300mv or 0.3 for SHALLOW we set to 400mv which is called biasLow or -3.6V
                    self.controller.biasLow()
                    await self.logMessage("Bias set to shallow: 400mv, -3.6")
                    await self.MESS.write("Bias set to shallow: 400mv, -3.6")
                    return True
                elif self.parent.arSetupH.value == "0.6":  # Seqexec uses 600mv or 0.6 for DEEP we set to 600mv which is called biasMed or -3.4V
                    self.controller.biasMed()
                    await self.logMessage("Bias set to deep: 600mv, -3.4")
                    await self.MESS.write("Bias set to deep: 600mv, -3.4")
                    return True
                else:
                    biasVal = float(self.parent.arSetupH.value)
                    await self.logMessage("Invalid bias voltage value. Leaving bias at: " + str(biasVal))
                    await self.MESS.write("Set Bias failed")
                    return False
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"BiasCAD error: {error_message}")
                await self.MESS.write(f"BiasCAD error: {error_message[:30]}")
                return False

                

class TDLCAD(GnirsCAD):
    async def start(self):
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            try:
                result = self.controller.testDataLink()
                await self.logMessage(f"TDL: {result}")
                await self.MESS.write("TDL successfull")
                return True
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"TDLCAD error: {error_message}")
                await self.MESS.write(f"TDL error: {error_message[:30]}")
                return False


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

            if (self.p.interlocked()):

                await self.logMessage(f"Detector not at temperature")
                await self.MESS.write("Detector not at temperature")

                return False
            else:
                self.controller = None

                await self.logMessage("SDSU Initializing")

            firmware_full_path = os.path.join(os.getcwd(), "firmware/AladdinIII_SDSU_Firmware.lod")

            # Calculate a fresh firmware checksum each time
            firmChecksum = calculate_firmware_checksum(firmware_full_path)
            await self.p.firmChecksum.write(firmChecksum)
            print(f"Firmware Checksum: {firmChecksum}")
            
            print(f"LOD Path: {firmware_full_path}")    
            # Normalize the path to resolve any symbolic links, ".." or "." etc.
            firmware_full_path = os.path.normpath(firmware_full_path)

            setGlobalDebug(DEBUG_MODE)
            self.controller = controllerInterface("/readout_data", firmware_full_path)

            self.controller.setAladdinIII(True)

            result = self.controller.testDataLink()

            if result:
                if self.controller.init():
                    await self.logMessage("SDSU Init successful")
                    await self.logMessage("Firm: " + self.p.firmChecksum.value)
                    await self.MESS.write("SDSU Init success sum: " + self.p.firmChecksum.value)
                    await self.MESS.write("Firm: " + self.p.firmChecksum.value)
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


class PowerOnCAD(GnirsCAD):
    async def start(self):
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        elif (self.p.interlocked()):
            await self.logMessage(f"Detector not at temperature")
            await self.MESS.write("Detector not at temperature")
            return False
        else:
            try:
                self.controller.powerOn()
                await self.logMessage("Voltage activation successful")
                await self.MESS.write("Voltage activation successful")
                return True
            
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"An exception occurred: {error_message}")
                await self.MESS.write(f"An exception occurred: {error_message}")
                return False
            

class PowerOffCAD(GnirsCAD):
    async def start(self):
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        elif (self.p.interlocked()):
            await self.logMessage(f"Detector not at temperature")
            await self.MESS.write("Detector not at temperature")
            return False
        else:
            try:
                self.controller.powerOff()
                await self.logMessage("Voltage deactivation successful")
                await self.MESS.write("Voltage deactivation successful")
                return True 
            
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"An exception occurred: {error_message}")
                await self.MESS.write(f"An exception occurred: {error_message}")
                return False


class DCConfigCAD(GnirsCAD):
    async def start(self):
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            try:
                self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, self.p.coaddsVAL.value, self.dropReadoutsNum.value, self.p.observeA.value)
                await self.MESS.write("Configuration Set Successfully")
                return True
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"DCConfigCAD error: {error_message}")
                await self.MESS.write(f"DCConfig error: {error_message[:30]}")
                return False


class AbortCAD(GnirsCAD):
    async def start(self):
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")
            return False
        else:
            try:
                # Abort the current exposure
                self.controller.abortExposure()
                
                # Set the sequence abort flag to stop any running sequence
                self.parent.sequence_abort = True
                
                await self.logMessage(f"Aborting Exposure and Sequence")
                await self.MESS.write("Abort Successful")
                return True
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"AbortCAD error: {error_message}")
                await self.MESS.write(f"Abort error: {error_message[:30]}")
                # Still set the abort flag even if controller call failed
                self.parent.sequence_abort = True
                return False


class ObserveCAD(GnirsCAD):

    async def start(self):
        if self.controller is None:
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not initialized")

            return False
        elif (self.p.interlocked()):

            await self.logMessage(f"Detector not at temperature")
            await self.MESS.write("Detector not at temperature")

            return False
        else:

            if (int(self.p.rdout.value) == 0):
                # Reset the sequence abort flag when starting a new sequence
                self.parent.sequence_abort = False

                if self.p.sequence.value < 1:
                    await self.p.sequence.write(1)

                for i in range(self.p.sequence.value, 0, -1):   # reverse and end at i = 1
                    # Check if sequence has been aborted
                    if self.parent.sequence_abort:
                        await self.logMessage(f"Sequence aborted after {self.p.sequence.value - i} exposures")
                        break
                        
                    # Add the timestamp to the observeA value if labelTimeStamp is greater than 0
                    # (labelTimeStamp is automatically enabled when sequence count > 1)
                    if self.p.labelTimeStamp.value > 0:
                        timestamp = get_current_timestamp()
                        await self.p.observeA.write(f"{timestamp}-{i}")

                    # Add fits extension if not going to archive
                    if self.p.parent.archive_fits.value == 0:
                        if not self.p.observeA.value.endswith('.fits'):
                            await self.p.observeA.write(f"{self.p.observeA.value}.fits")

                    # begin readout
                    try:
                        if not await self.setBias():
                            await self.MESS.write("Observe failed - setBias error")
                            return False
                        self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, int(self.p.coaddsVAL.value), int(self.p.dropReadoutsNum.value), self.p.observeA.value)
                        exposure_delay = self.controller.getExposureDelay(self.p.exposureTime.value, int(self.p.lnrNum.value), int(self.p.digitalAvgs.value))
                    except Exception as e:
                        error_message = str(e)
                        await self.logMessage(f"Observe setup error: {error_message}")
                        await self.MESS.write(f"Observe error: {error_message[:30]}")
                        return False

                    await self.p.rdout.write(1)


                    # Run countdown_timer in a separate thread to prevent blocking
                    countdown_task = asyncio.create_task(self.countdown_timer(exposure_delay))

                    try:
                        await self.start_async_exposure()
                    except Exception as e:
                        # Cancel countdown timer on error
                        if not countdown_task.done():
                            countdown_task.cancel()
                        await self.p.obsProgress.write(0)
                        await self.p.coaddProgress.write(0)
                        await self.p.timeLeft.write('0')
                        error_message = str(e)
                        await self.logMessage(f"Exposure failed: {error_message}")
                        await self.MESS.write(f"Exposure failed: {error_message[:25]}")
                        return False
                    
                    # Cancel the countdown timer task after exposure completes
                    if not countdown_task.done():
                        countdown_task.cancel()
                        # Ensure final values are set to 0% when cancelled
                        await self.p.obsProgress.write(0)
                        await self.p.coaddProgress.write(0)
                        await self.p.timeLeft.write('0')
                    
                    await self.p.sequenceLeft.write(i) # keep track of the remaining exposures
                                                       # end at 1 so it will do a single exposure if sequence is not manually set



                # Reset the sequence abort flag at the end of the sequence
                self.parent.sequence_abort = False
                
                # reset all manual parameters to default values
                # set sequence to 1
                await self.p.sequence.write(1)
                # disable timestamp
                await self.p.labelTimeStamp.write(0)
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

        # Get the current TCS context
        tcs_context = await self.parent.get_wcs_context()

        if tcs_context is None:
            await self.logMessage("Failed to get TCS context. Continuing without it.")
        else:
            # Log the TCS context
            await self.logMessage(f'TCS Context: {tcs_context}')

            # Send TCS context separately
            try:
                self.controller.setTCSContext(tcs_context)
            except Exception as e:
                await self.logMessage(f"setTCSContext error: {str(e)}. Continuing without TCS context.")

        # readout SDSU
        try:
            self.controller.startExposure(
                self.p.detectorTemp1.value, 
                self.p.detectorTemp2.value, 
                self.p.parent.include_eng.value
            )
        except Exception as e:
            error_message = str(e)
            await self.logMessage(f"startExposure error: {error_message}")
            await self.MESS.write(f"Exposure error: {error_message[:30]}")
            await self.p.rdout.write(0)
            raise

        await self.logMessage(f'SDSU readout started')

        #while self.controller.getReadingOut(): 
        try:
            while await asyncio.to_thread(self.controller.getReadingOut):
                await asyncio.sleep(0.1)
        except Exception as e:
            error_message = str(e)
            await self.logMessage(f"getReadingOut error: {error_message}")
            await self.MESS.write(f"Readout error: {error_message[:30]}")
            await self.p.rdout.write(0)
            raise

        await self.logMessage(f'SDSU readout complete')

        # if sending to archive let GDS know
        if (self.p.parent.archive_fits.value):
            self.giapi.observeEndReadout(self.p.observeA.value)

            #await self.logMessage(f'GDS writing fits')

            #self.giapi.observeStartWrite(self.p.observeA.value)

            #self.giapi.observeEndWrite(self.p.observeA.value)

        #complete readout
        await self.logMessage(f'ObserveCAD end')
                                         
        # set write to fits archive by default don't want a test write to affect a seqexec readout
        #await self.p.parent.archive_fits.write(1)
        # and turn off raw data
        #await self.p.parent.include_eng.write(0)


        await self.p.rdout.write(0)





    async def countdown_timer(self, single_readout_time):
        if single_readout_time <= 0.2:  # about minimum readout time 
            single_readout_time = 0.2

        total_coadds = int(self.p.coaddsVAL.value)
        if total_coadds <= 0:  # Guard against zero or negative coadds
            total_coadds = 1
        total_time = single_readout_time * total_coadds
        start_time = time.time()
        

        # Reset progress values at the start of a new exposure
        await self.p.obsProgress.write(0)
        await self.p.coaddProgress.write(0)
        await self.p.timeLeft.write(str(total_time))

        while self.p.rdout.value > 0:
            current_time = time.time()
            elapsed_time = current_time - start_time
            remaining_time = max(total_time - elapsed_time, 0)

            # Update timeLeft
            await self.p.timeLeft.write(str(remaining_time))

            # Calculate and update total progress
            total_progress = min((elapsed_time / total_time) * 100, 100)
            await self.p.obsProgress.write(total_progress)

            # Calculate and update coadd progress
            coadds_completed = min(int(elapsed_time / single_readout_time), total_coadds)
            coadd_progress = (coadds_completed / total_coadds) * 100
            await self.p.coaddProgress.write(coadd_progress)

            await asyncio.sleep(0.1)  # Update every 0.1 seconds

        # Ensure final values are set to 100% when complete
        await self.p.obsProgress.write(100)
        await self.p.coaddProgress.write(100)
        await self.p.timeLeft.write('0')
    
    async def setBias(self):
            biasVal = float(self.parent.arSetupH.value)

            try:
                if self.parent.arSetupH.value == "0.3":  # Seqexec uses 300mv or 0.3 for SHALLOW we set to 400mv which is called biasLow or -3.6V
                    self.controller.biasLow()
                    await self.logMessage("Bias set to shallow: 400mv, -3.6")
                    await self.MESS.write("Bias set to shallow: 400mv, -3.6")
                    return True
                elif self.parent.arSetupH.value == "0.6":  # Seqexec uses 600mv or 0.6 for DEEP we set to 600mv which is called biasMed or -3.4V
                    self.controller.biasMed()
                    await self.logMessage("Bias set to deep: 600mv, -3.4")
                    await self.MESS.write("Bias set to deep: 600mv, -3.4")
                    return True
                else:
                    await self.logMessage("Invalid bias voltage value. Leaving bias at: " + str(biasVal))
                    await self.MESS.write("Set Bias failed")
                    return False
            except Exception as e:
                error_message = str(e)
                await self.logMessage(f"setBias error: {error_message}")
                await self.MESS.write(f"setBias error: {error_message[:30]}")
                return False




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
    powerOn = SubGroup(PowerOnCAD, prefix='dc:powerOn.')
    powerOff = SubGroup(PowerOffCAD, prefix='dc:powerOff.')
    dcconfig = SubGroup(DCConfigCAD, prefix='dc:dcconfig.')
    endObserve = SubGroup(AbortCAD, prefix='dc:endObserve.')
    abort = SubGroup(AbortCAD, prefix='dc:abort.')
    stop = SubGroup(AbortCAD, prefix='dc:stop.')
    observe = SubGroup(ObserveCAD, prefix='dc:observe.')
    observeC = SubGroup(CARRecord, prefix='dc:observeC.')


    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        print(f"Debug mode: {DEBUG_MODE}")

        # Add flag to track if a sequence should be aborted
        self.sequence_abort = False

        self.lakeshore = Lakeshore325(TEMP_CON_IP, TEMP_CON_PORT)
        self.lakeshore.connect()

        # Initialize TCS Monitor
        self.tcs_monitor = TCSMonitor()
        self.tcs_monitor.initialize()

        self.sdsuController = None

        self.abort.set_idle_override(True)  # allows this cad to execute while other cads are busy in order to abort them

        # CAD commands connect to top level CAR record
#        for cmd in [self.dcconfig, self.endObserve, self.abort, self.observe, self.stop]:
#            cmd.car_record = self.applyC

        # Apply command connects to CAD/CAR records
        self.apply.cars.records = [self.applyC]
        #self.apply.cads.records = [self.dcconfig, self.observe]


        # some kind of order bug. observe must go first or seqexec will error ?? 
        self.apply.cads.records = [self.observe, self.dcconfig, self.endObserve, self.abort, self.observe, self.stop, self.init, self.initSDSU, self.powerOn, self.powerOff, self.TDL, self.bias]

        # Observe has it's own CAR
        self.observe.cars.records = [self.observeC]
        self.observeC.cars.records = [self.applyC]


    async def get_wcs_context(self):
        try:
            tcs_context = self.tcs_monitor.get_context()
            if not tcs_context:
                raise ValueError("Failed to get TCS context")
            
            wcs_file = choose_file(int(tcs_context.port), tcs_context.camera, tcs_context.ao)
            if not wcs_file:
                raise ValueError("Failed to choose WCS file")

            await self.parent.wcs_file.write(wcs_file)

            return tcs_context
        except Exception as e:
            await self.parent.logMessage(f"Error in get_wcs_context: {str(e)}")
            return None


    ntp_time = pvproperty(value='0.0', dtype=caproto.ChannelType.STRING, read_only=True, doc="Current NTP time in MJD")

    @ntp_time.scan(period=0.1)  # Scan every 0.1 second
    async def ntp_time(self, instance, async_lib):
        try:
            ntp_time = self.tcs_monitor.get_ntp_time()
            if ntp_time is None:
                # Fallback to system time if TCS NTP time is not available
                current_time = time.time()
                mjd = (current_time / 86400.0) + 40587  # Convert Unix timestamp to MJD
                ntp_time = f"{mjd:.6f}"
            await instance.write(str(ntp_time))
        except Exception as e:
            print(f"Error getting NTP time: {str(e)}")
            await instance.write("Error")

    #------ DC configuration values --------

    #------ fowlers - lnr -------------------
    obsSetupD      = pvproperty(value='1', dtype=caproto.ChannelType.STRING, name="dc:obsSetup.D", doc = "")
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
    obsSetupC      = pvproperty(value='1', dtype=caproto.ChannelType.STRING, name="dc:obsSetup.C", doc = "")
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
    temperature = pvproperty(value=-999.0, read_only=True, dtype=caproto.ChannelType.DOUBLE, name="dc:temperature")

    @temperature.startup
    async def temperature(self, instance, async_lib):
        await self.parent.logMessage(f"Temperature Interlock: {INTERLOCK_TEMP}")

    @temperature.scan(period=5)  # Scan every 5 seconds
    async def temperature(self, instance, async_lib):
        try:
            temp = self.lakeshore.read_temperature()
            if temp is not None:
                await instance.write(temp)
        except Exception as e:
            return

    temperature_status  = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="dc:temperature_status")    
    @temperature_status.scan(period=5)  # Scan every 5 seconds (sped up from 60)
    async def temperature_status(self, instance, async_lib):
        try:
            status = self.lakeshore.check_status()
            if status is not None:
                status_string = status[:40].ljust(40)
                await instance.write(status_string)
            else:
                print("Status reading returned None")
        except Exception as e:
            print(f"Error reading status: {e}")

    # Duplicate temperature channel as dc:C1Tmp - reads from existing temperature PV
    c1_tmp = pvproperty(value=-999.0, read_only=True, dtype=caproto.ChannelType.DOUBLE, name="dc:C1Tmp")

    @c1_tmp.scan(period=5)  # Scan every 5 second to copy temperature value
    async def c1_tmp(self, instance, async_lib):
        # Simply copy the value from the existing temperature PV
        await instance.write(self.temperature.value)

    disable_interlock  = pvproperty(value=0, dtype=caproto.ChannelType.INT, name="dc:disable_interlock")    

    def interlocked(self): 
        if ((self.temperature.value > INTERLOCK_TEMP or self.temperature.value == -999) and self.disable_interlock.value <= 0):
            return True
        else:
            return False

    #-------------- Temp Monitor -------------------



    #------ DC configuration values --------
    sequence        = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:sequence", doc = "Sequence Count") 
    @sequence.putter
    async def sequence(self, instance, value):
        await self.sequenceLeft.write(value)
        # Auto enable timestamp labeling when sequence count is greater than 1
        if value > 1:
            await self.labelTimeStamp.write(1)
            await self.parent.logMessage(f"Auto-enabled timestamp labeling for sequence of {value}")
        # If sequence count is 1, no need to change the timestamp setting as it will
        # be reset at the end of the exposure sequence


    sequenceLeft    = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:sequenceLeft", doc = "Exposures left to readout")

    sdsuState       = pvproperty(value='NOT INITIALIZED', dtype=caproto.ChannelType.STRING, name="dc:sdsuState", doc = "SDSU Controller State") 

    # arSetupH is the process variable (PV) that Seqexec uses to adjust and control the bias levels for the detector.
    arSetupH       = pvproperty(value='0.6', dtype=caproto.ChannelType.STRING, name="dc:arSetup.H", doc="")
    @arSetupH.putter
    async def arSetupH(self, instance, value):
        try:
            # Convert the string value to float
            float_value = float(value)
            # Update achvdBias with the new value
            await self.achvdBias.write(float_value)
        except ValueError:
            # If the conversion fails, log an error
            await self.parent.logMessage(f"Invalid value for arSetupH: {value}")

    achvdBias       = pvproperty(value=0.6, dtype=caproto.ChannelType.DOUBLE, name="dc:achvdBias.VAL", doc = "Achieved Detector Bias")


    detBias         = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:detBias", doc = "Detector Bias") 
    wcs             = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="dc:wcs", doc = "WCS file") 



    dataLabel       = pvproperty(value='datalabel', dtype=caproto.ChannelType.STRING, name="dc:dataLabel", doc = "Data Label") 
    firmChecksum    = pvproperty(value='firmchecksum', dtype=caproto.ChannelType.STRING, name="dc:firmChecksum", doc = "Firmware Checksum") 

    @firmChecksum.startup
    async def firmChecksum(self, instance, async_lib):
        # Calculate the checksum on startup
        firmware_path = os.path.join(os.getcwd(), "firmware/AladdinIII_SDSU_Firmware.lod")
        checksum = calculate_firmware_checksum(firmware_path)
        await instance.write(checksum)

    detectorTemp1   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp1", doc = "Detector Temperature 1")
    detectorTemp2   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp2", doc = "Detector Temperature 2")

    timeLeft        = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="sad:dc:timeLeft", doc = "Exposure time left") 
    obsProgress     = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsProgress", doc = "Exposure percent complete") 
    coaddProgress   = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:coaddProgress", doc = "Coadd percent complete") 


    setWcsA        = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="dc:setWcs.A", doc = "")


    detIDVAL       = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="sad:dc:detID.VAL", doc = "")
    detTypeVAL     = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="sad:dc:detType.VAL", doc = "")
    obsepoch       = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsepoch", doc = "")
    setWcsVALA     = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="dc:setWcs.VALA", doc = "")

    obsSetupVALC   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name=  "dc:obsSetup.VALC", doc = "")
    obsSetupVALD   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name=  "dc:obsSetup.VALD", doc = "")
    obsSetupVALE   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name=  "dc:obsSetup.VALE", doc = "")

    dhsConnected   = pvproperty(value=1, dtype=caproto.ChannelType.LONG, name=  "sad:dc:dhsConnected", doc = "")
    minIntVAL      = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:minInt.VAL", doc = "")



    prep           = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="sad:dc:prep", doc = "")
    acq            = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="sad:dc:acq", doc = "")
    rdout           = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="sad:dc:rdout", doc = "Reading out") 

    labelTimeStamp = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:labelTimeStamp", doc = "add timestamp to file label") 


    activate       = pvproperty(value=1, dtype=caproto.ChannelType.ENUM, enum_strings=['Deactivate', 'Activate'], name="dc:activate", doc = "")



    observeA       = pvproperty(value='eng_readout', dtype=caproto.ChannelType.STRING, name="dc:observe.A", doc = "")

    @observeA.putter
    async def observeA(self, instance, value):
        await self.parent.logMessage(f"Data Label: {value}")

        ## obsSetupA has a forward link to observeCAD to mark it so it will process
        # seqexec never sets observe CAD DIR to MARK so it is done manually here

        await self.observe.DIR.write(CADDirective.MARK)

        #await self.labelTimeStamp.write(0) # turn off time stamps - seqexec will handle the name
        await self.dataLabel.write(value)


def calculate_firmware_checksum(firmware_path):
    """Calculate the MD5 checksum of the firmware file."""
    try:
        if not os.path.exists(firmware_path):
            print(f"Firmware file not found at {firmware_path}")
            return "file_not_found"
        
        with open(firmware_path, 'rb') as f:
            content = f.read()
            # Using MD5 to match Linux md5sum command
            md5sum = hashlib.md5(content).hexdigest()
        print(f"Calculated firmware checksum: {md5sum}")
        return md5sum
    except Exception as e:
        print(f"Error calculating firmware checksum: {str(e)}")
        return "checksum_error"


