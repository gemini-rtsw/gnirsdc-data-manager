import caproto
from caproto.server import pvproperty, SubGroup, PVGroup, ioc_arg_parser, run
from pygeminirec.applyrecord import ApplyRecord
from pygeminirec.cadrecord import CADRecord
from pygeminirec.carrecord import CARRecord

import asyncio
from concurrent.futures import ThreadPoolExecutor

from time import sleep


from libgnirsioc import controllerInterface
from libgnirsioc import controllerInterfaceDebug

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
        self.controller.setExposure(self.p.lnrNum.value, self.p.digitalAvgs.value, self.p.exposureTime.value, self.p.sequence.value)
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
            loop = asyncio.get_event_loop()
            executor = ThreadPoolExecutor()
            loop.run_in_executor(executor, asyncio.run, self.start_async())
        else:
            await self.logMessage(f'Readout in progress')

    async def start_async(self):

            await self.p.rdout.write(1)

            await self.logMessage(f'{self.prefix} ObserveCAD start')
            print(f'{self.prefix} ObserveCAD start')

            self.giapi.setDataLabel(self.p.dataLabel.value)
            await self.logMessage(f'DataLabel: {self.giapi.dataLabel}')
            
            await self.logMessage(f'sending observe prep to GMP')

            self.giapi.observePrep()
            self.giapi.observeStartAcq()
            self.giapi.observeEndAcq()

            await self.logMessage(f'sending start readout to GMP')

            self.giapi.observeStartReadout()

            await self.logMessage(f'sending start readout to SDSU')

            self.controller.startExposure(self.p.detectorTemp1.value, self.p.detectorTemp1.value, False);	
            sleep(self.p.exposureTime.value)


            await self.logMessage(f'SDSU readout complete')
            await self.logMessage(f'descrambling raw data')

            self.giapi.observeEndReadout()

            await self.logMessage(f'GDS writing fits')

            self.giapi.observeStartWrite()

            self.giapi.observeEndWrite()

            await self.logMessage(f'ObserveCAD end')

            await self.p.rdout.write(0)



class StopCAD(GnirsCAD):
    async def start(self):
        print("StopCAD start")


class GnirsCADCARController(PVGroup):

    sdsuController = controllerInterfaceDebug()

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

    timeLeft        = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="sad:dc:timeLeft", doc = "Exposure time left") 
    rdout           = pvproperty(value=0, dtype=caproto.ChannelType.INT, name="sad:dc:rdout", doc = "Reading out") 

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # CAD commands connect to top level CAR record
        self.dcconfig.car_record = self.applyC
        self.endObserve.car_record = self.applyC
        self.abort.car_record = self.applyC
        self.observe.car_record = self.applyC
        self.stop.car_record = self.applyC

        # Apply command connects to CAD records
        self.apply.sub_records = [self.dcconfig,self.endObserve, self.abort, self.observe, self.stop, self.init, self.initSDSU, self.TDL0, self.TDL1, self.bias]






    

