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


import time

import os

from libgnirsioc import controllerInterface
from libgnirsioc import controllerInterfaceDebug




DEBUG_MODE = True

def DebugMode(value):
    global DEBUG_MODE
    DEBUG_MODE = value
    print(f"Value: {DEBUG_MODE}")





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
        if (self.controller == None):
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
        if (self.controller == None):
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

                result = self.controller.testDataLink()

                if result:
                    if self.controller.init():
                        await self.logMessage("SDSU Initialization successful")
                        await self.MESS.write("SDSU Initialization successful")
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
        if (self.controller == None):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not Initialized")
            return False
        else:
            self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, self.p.coaddsVAL.value)
            await self.logMessage(f"Config lnr: {self.p.lnrNum.value} adc: {self.p.digitalAvgs.value} exp: {self.p.exposureTime.value} coadds: {self.p.coaddsVAL.value}")
            await self.MESS.write("Configuration Set Successfully")
            return True


class AbortCAD(GnirsCAD):
    async def start(self):
        if (self.controller == None):
            await self.logMessage(f"Controller not initialized")
            await self.MESS.write("Controller not Initialized")
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
            await self.MESS.write("Controller not Initialized")
            return False
        else:
            if (int(self.p.rdout.value) == 0):
                
                #begin readout
                await self.p.rdout.write(1)


                # Run the blocking function in a separate thread
                self.loop = asyncio.get_event_loop()

                exposure_task = asyncio.create_task(
                    asyncio.to_thread(self.start_async_exposure)
                )
                countdown_task = asyncio.create_task(
                    self.countdown_timer(self.p.exposureTime.value)
                )


                # wait for observe to complete
                while(self.p.rdout.value == 1):
                    await asyncio.sleep(0.01)


                await self.MESS.write("Observe CAD Completed Successfully")
                return True
   
            else:
                await self.logMessage(f'Readout in progress')
                await self.MESS.write("Observe Failure - Readout in Progress")
                return False

    def start_async_exposure(self):
        """
        Manages the process of starting an asynchronous exposure sequence, including logging, readout, and archiving.

        This function handles various tasks such as logging messages, starting and ending the exposure,
        sending notifications to different systems (like GMP and SDSU), and managing data archival processes.
        It uses asyncio for concurrency, running coroutines in a specified event loop.

        Parameters:
        self: Reference to the class instance where methods like 'logMessage', 'write_coadds_header', and attributes
            like 'p.exposureTime', 'p.detectorTemp1', 'giapi' are defined.
        loop: The asyncio event loop in which to run asynchronous tasks.

        The function performs different actions based on the 'archive_fits' value and the exposure time.
        It's designed to work with a specific system setup, handling both the observational and data handling aspects.
        """
        asyncio.run_coroutine_threadsafe(self.logMessage(f'{self.prefix} ObserveCAD start'), self.loop)
        print(f'{self.prefix} ObserveCAD start')

        #self.write_coadds_header()

        # if sending to archive let GDS know
        if (self.p.parent.archive_fits.value):
            self.giapi.setDataLabel(self.p.dataLabel.value)
            asyncio.run_coroutine_threadsafe(self.logMessage(f'DataLabel: {self.giapi.dataLabel}'), self.loop)
        
            asyncio.run_coroutine_threadsafe(self.logMessage(f'sending observe prep to GMP'), self.loop)

            self.giapi.observePrep()
            self.giapi.observeStartAcq()
            self.giapi.observeEndAcq()

            asyncio.run_coroutine_threadsafe(self.logMessage(f'sending start readout to GMP'), self.loop)

            self.giapi.observeStartReadout()

            asyncio.run_coroutine_threadsafe(self.logMessage(f'sending start readout to SDSU'), self.loop)


        # readout SDSU
        sleep(self.p.exposureTime.value/2)        
        self.controller.startExposure(self.p.detectorTemp1.value, self.p.detectorTemp1.value, self.p.parent.include_eng.value)	
        sleep(self.p.exposureTime.value/2)        


        asyncio.run_coroutine_threadsafe(self.logMessage(f'SDSU readout complete'), self.loop)
        asyncio.run_coroutine_threadsafe(self.logMessage(f'descrambling raw data'), self.loop)

        # if sending to archive let GDS know
        if (self.p.parent.archive_fits.value):
            self.giapi.observeEndReadout()

            asyncio.run_coroutine_threadsafe(self.logMessage(f'GDS writing fits'), self.loop)

            self.giapi.observeStartWrite()

            self.giapi.observeEndWrite()

        #complete readout
        asyncio.run_coroutine_threadsafe(self.logMessage(f'ObserveCAD end'), self.loop)

        # set write to fits archive by default don't want a test write to affect a seqexec readout
        asyncio.run_coroutine_threadsafe(self.p.parent.archive_fits.write(1), self.loop)
        # and turn off raw data
        asyncio.run_coroutine_threadsafe(self.p.parent.include_eng.write(0), self.loop)


        asyncio.run_coroutine_threadsafe(self.p.rdout.write(0), self.loop)






    async def countdown_timer(self, total_time):
        """
        Asynchronously runs a countdown timer for the specified total time.

        This function periodically updates the remaining time and prints it,
        along with a specific prefix, to the console. It also writes the remaining time and 
        observation progress as percentages to their respective properties in the class.

        Parameters:
        self: Reference to the class instance where 'p.rdout', 'p.timeLeft', and 'p.obsProgress' are defined.
        total_time: The total time for the countdown in seconds.

        The countdown stops when the remaining time reaches zero or when 'self.p.rdout' is False.
        """
        print("countdown_timer start")
        start_time = time.time()  # Get the current time in seconds
        remaining_time = total_time
        
        while remaining_time > 0 and self.p.rdout:
            current_time = time.time()  # Get the current time in seconds
            elapsed_time = current_time - start_time  # Calculate elapsed time
            remaining_time -= elapsed_time  # Subtract elapsed time from remaining time
            start_time = current_time  # Update the start time
            
            print(f'{self.prefix} countdown_timer: {remaining_time:.1f}')
            await asyncio.sleep(0.1)  # You can keep a constant sleep interval here
            await self.p.timeLeft.write(str(remaining_time))
            await self.p.obsProgress.write(100 - (remaining_time/total_time)*100)



    def write_coadds_header(self):
        """
        Writes content to a file with a '.coadds' extension.
        The file is named based on the 'dataLabel' attribute and saved in the directory specified by 'data_dir'.
        The file specifies the number of fits that will be coadded.

        Parameters:
        self: Reference to the class instance where 'p.parent.data_dir.value' and 'p.dataLabel.value' are defined.
        content: The content to be written to the file.
        """
        directory = self.p.parent.data_dir.value
        file_name = self.p.dataLabel.value + ".coadds"

        # Create the full path
        full_path = os.path.join(directory + "/new", file_name)

        # Write to the file
        with open(full_path, 'w') as file:
            file.write(f"coadds: {self.p.coaddsVAL.value}\n")
            file.write(f"eng: {self.p.parent.include_eng.value}\n")

    
        #run thread safe async to set the eng write false after every fits
        asyncio.run_coroutine_threadsafe(self.p.parent.include_eng.write(0), self.loop)





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
    obsSetupD      = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:obsSetup.D", doc = "")
    @obsSetupD.putter
    async def obsSetupD(self, instance, value):
        if (self.lnrNum.value != int(value)):
            await self.lnrNum.write(int(value))


    lnrNum          = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:lnrNum", doc = "Low Noise Reads") 
    @lnrNum.putter
    async def lnrNum(self, instance, value):

        if (self.sdsuController == None):
            await self.parent.logMessage(f"Controller not initialized")
        else:
            self.sdsuController.setExposure(value, self.digitalAvgs.value, self.exposureTime.value, int(self.coaddsVAL.value))
            await self.parent.logMessage(f"LNR: {value}")
    #------ fowlers - lnr -------------------

    #-------------- exposureTime -------------------
    exposureTime    = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:exposureTime", doc = "Exposure Time") 
    @exposureTime.putter
    async def exposureTime(self, instance, value):
        if (self.sdsuController == None):
            await self.parent.logMessage(f"Controller not initialized")
        else: 
            self.sdsuController.setExposure(value, self.digitalAvgs.value, self.exposureTime.value, int(self.coaddsVAL.value))
            await self.parent.logMessage(f"Exposure Time: {value}")
    #-------------- exposureTime -------------------



    #-------------- digitalAvgs -------------------
    obsSetupC      = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:obsSetup.C", doc = "")
    @obsSetupC.putter
    async def obsSetupC(self, instance, value):
        if (self.digitalAvgs.value != int(value)):
            await self.digitalAvgs.write(int(value))

    digitalAvgs     = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:digitalAvgs", doc = "Digital Averages") 
    @digitalAvgs.putter
    async def digitalAvgs(self, instance, value):

        if (self.sdsuController == None):
            await self.parent.logMessage(f"Controller not initialized")
        else: 
            self.sdsuController.setExposure(self.lnrNum.value, value, self.exposureTime.value, int(self.coaddsVAL.value))
            await self.parent.logMessage(f"ADC: {value}")
    #-------------- digitalAvgs -------------------




    #-------------- coadds -------------------
    coaddsVAL      = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:coadds.VAL", doc = "")
    @coaddsVAL.putter
    async def coaddsVAL(self, instance, value):
        if (self.sdsuController == None):
            await self.parent.logMessage(f"Controller not initialized")
        else:
            await self.obsSetupVALE.write(value)             
            self.sdsuController.setExposure(self.lnrNum.value, self.digitalAvgs.value, self.exposureTime.value, int(value))
            await self.parent.logMessage(f"Coadds: {value}")
    #-------------- coadds -------------------

    #------ DC configuration values --------


    achvdBias       = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:achvdBias.VAL", doc = "Achieved Detector Bias") 


    detBias         = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:detBias", doc = "Detector Bias") 
    sequence        = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:sequence", doc = "Sequence Count") 
    wcs             = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="dc:wcs", doc = "WCS file") 



    dataLabel       = pvproperty(value='GN20231011S1800', dtype=caproto.ChannelType.STRING, name="dc:dataLabel", doc = "Data Label") 


    detectorTemp1   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp1", doc = "Detector Temperature 1")
    detectorTemp2   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp2", doc = "Detector Temperature 2")

    timeLeft        = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="sad:dc:timeLeft", doc = "Exposure time left") 
    obsProgress     = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsProgress", doc = "Exposure percent complete") 

    rdout           = pvproperty(value=0, dtype=caproto.ChannelType.INT, name="sad:dc:rdout", doc = "Reading out") 

    setWcsA        = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:setWcs.A", doc = "")


    arSetupH       = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:arSetup.H", doc = "")
    detIDVAL       = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="sad:dc:detID.VAL", doc = "")
    detTypeVAL     = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="sad:dc:detType.VAL", doc = "")
    obsepoch       = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsepoch", doc = "")
    setWcsVALA     = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:setWcs.VALA", doc = "")

    obsSetupVALC   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:obsSetup.VALC", doc = "")
    obsSetupVALD   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:obsSetup.VALD", doc = "")
    obsSetupVALE   = pvproperty(value=0, dtype=caproto.ChannelType.LONG, name="dc:obsSetup.VALE", doc = "")

    dhsConnected   = pvproperty(value=1, dtype=caproto.ChannelType.LONG, name="sad:dc:dhsConnected", doc = "")
    minIntVAL      = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:minInt.VAL", doc = "")
    C1Tmp          = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:C1Tmp", doc = "")
    prep           = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="sad:dc:prep", doc = "")
    acq            = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="sad:dc:acq", doc = "")
    activate       = pvproperty(value=1, dtype=caproto.ChannelType.ENUM, enum_strings=['Deactivate', 'Activate'], name="dc:activate", doc = "")
    integTimeVAL   = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:integTime.VAL", doc = "")


## obsSetupD needs a forward link to observeCAD to mark it to process
# this is a seqexec thing. for observe CAD DIR never gets set to MARK
    observeA       = pvproperty(value=0, dtype=caproto.ChannelType.STRING, name="dc:observe.A", doc = "")

    @observeA.putter
    async def observeA(self, instance, value):
        print(f"Value changed to: {value}")
        await self.observe.DIR.write(CADDirective.MARK)
        await self.dataLabel.write(value)






