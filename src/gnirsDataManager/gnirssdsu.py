import caproto
from caproto.server import pvproperty, SubGroup, PVGroup, ioc_arg_parser, run
from pygeminirec.applyrecord import ApplyRecord
from pygeminirec.cadrecord import CADRecord
from pygeminirec.carrecord import CARRecord

import asyncio
from concurrent.futures import ThreadPoolExecutor

from time import sleep

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
        self.controller = self.parent.sdsuController
        self.giapi = self.parent.parent.GIAPIInterface
        self.logMessage = self.parent.parent.logMessage
        self.p = self.parent


class InitCAD(GnirsCAD):
    async def start(self):
        print("InitCAD start")

        await self.logMessage("InitCAD start")


class BiasCAD(GnirsCAD):
    async def start(self):
        print("BiasCAD start")
        
        biasVal = self.parent.detBias.value

        if (biasVal == -3.6):
            self.controller.biasLow()
            await self.logMessage("Bias set to shallow: -3.6")
        elif (biasVal == -3.2):
            self.controller.biasHigh()
            await self.logMessage("Bias set to deep: -3.2")
        else:
            await self.logMessage("Invalid bias voltage value. Leaving bias at: " + str(biasVal))
            

class TDL0CAD(GnirsCAD):
    async def start(self):
        print("TDL0 start")
        await self.logMessage("TDL0 start")

class TDL1CAD(GnirsCAD):
    async def start(self):
        print("TDL1 start")   
        await self.logMessage("TDL1 start")
        

class InitSDSUCAD(GnirsCAD):
    async def start(self):
        print("InitSDSUCAD start")
        self.controller.setAladdinIII(True)
        self.controller.init()

        await self.logMessage("SDSU Initialized")


class DCConfigCAD(GnirsCAD):
    async def start(self):
        print(f'{self.prefix} START DC Config')
        self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, self.p.sequence.value * self.p.coadds)
        await self.logMessage("f'{self.prefix} START DC Config'")

class EndObserveCAD(GnirsCAD):
    async def start(self):
        print("endObserve start")
        await self.logMessage("endObserve start")

class AbortCAD(GnirsCAD):
    async def start(self):
        print("AbortCAD start")        
        await self.logMessage("AbortCAD start")


class ObserveCAD(GnirsCAD):
    async def start(self):
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

#            loop = asyncio.get_event_loop()
#            executor = ThreadPoolExecutor()
#            loop.run_in_executor(executor, asyncio.run, self.start_async_exposure())
#            loop.run_in_executor(executor, asyncio.run, self.countdown_timer(self.p.exposureTime.value))    
        else:
            await self.logMessage(f'Readout in progress')

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

        self.write_coadds_header()

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
        self.controller.startExposure(self.p.detectorTemp1.value, self.p.detectorTemp1.value, False)	
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
            file.write(f"coadds: {self.p.numcoadds.value}\n")
            file.write(f"sequence: {self.p.sequence.value}\n")
            file.write(f"eng: {self.p.parent.include_eng.value}\n")

    
        #run thread safe async to set the eng write false after every fits
        asyncio.run_coroutine_threadsafe(self.p.parent.include_eng.write(0), self.loop)





class StopCAD(GnirsCAD):
    async def start(self):
        print("StopCAD start")


class GnirsCADCARController(PVGroup):

    def __init__(self, *args, **kwargs):

        print (f"Debug mode: {DEBUG_MODE}")

        if (DEBUG_MODE):
            print("DEBUG MODE ENABLED")
            self.sdsuController = controllerInterfaceDebug()
        else:
            print("SDSU Initializing")
            self.sdsuController = controllerInterface()

        super().__init__(*args, **kwargs)


        # CAD commands connect to top level CAR record
        self.dcconfig.car_record = self.applyC
        self.endObserve.car_record = self.applyC
        self.abort.car_record = self.applyC
        self.observe.car_record = self.applyC
        self.stop.car_record = self.applyC

        # Apply command connects to CAD records
        self.apply.sub_records = [self.dcconfig,self.endObserve, self.abort, self.observe, self.stop, self.init, self.initSDSU, self.TDL0, self.TDL1, self.bias]






    #------ CAD commands --------
    # dc:TDL
    TDL0 = SubGroup(TDL0CAD, prefix='dc:TDL0.')
    TDL1 = SubGroup(TDL1CAD, prefix='dc:TDL1.')

    # dc:bias  
    bias = SubGroup(BiasCAD, prefix='dc:bias.')

    # dc:init
    init = SubGroup(InitCAD, prefix='dc:init.')
    initSDSU = SubGroup(InitSDSUCAD, prefix='dc:initSDSU.')

    # dc:apply
    dcconfig = SubGroup(DCConfigCAD, prefix='dc:dcconfig.')
    endObserve = SubGroup(EndObserveCAD, prefix='dc:endObserve.')
    abort = SubGroup(AbortCAD, prefix='dc:abort.')
    observe = SubGroup(ObserveCAD, prefix='dc:observe.')
    stop = SubGroup(StopCAD, prefix='dc:stop.')
        

    applyC = SubGroup(CARRecord, prefix='dc:applyC.')
    apply = SubGroup(ApplyRecord, prefix='dc:apply.')

    #------ DC configuration values --------
    lnrNum          = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:lnrNum", doc = "Low Noise Reads") 
    exposureTime    = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="dc:exposureTime", doc = "Exposure Time") 
    wcs             = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="dc:wcs", doc = "WCS file") 
    digitalAvgs     = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:digitalAvgs", doc = "Digital Averages") 
    detBias         = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="dc:detBias", doc = "Detector Bias") 
    numcoadds       = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:numcoadds", doc = "Number of Coadds") 
    sequence        = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="dc:sequence", doc = "Sequence Count") 

    dataLabel       = pvproperty(value='GN20231011S1800', dtype=caproto.ChannelType.STRING, name="dc:dataLabel", doc = "Data Label") 


    detectorTemp1   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp1", doc = "Detector Temperature 1")
    detectorTemp2   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="dc:detectorTemp2", doc = "Detector Temperature 2")

    timeLeft        = pvproperty(value='0', dtype=caproto.ChannelType.STRING, name="sad:dc:timeLeft", doc = "Exposure time left") 
    obsProgress     = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="sad:dc:obsProgress", doc = "Exposure percent complete") 

    rdout           = pvproperty(value=0, dtype=caproto.ChannelType.INT, name="sad:dc:rdout", doc = "Reading out") 






    

