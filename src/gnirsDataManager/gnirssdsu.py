import caproto
from caproto.server import pvproperty, SubGroup, PVGroup, ioc_arg_parser, run
from pygeminirec.applyrecord import ApplyRecord
from pygeminirec.cadrecord import CADRecord
from pygeminirec.carrecord import CARRecord
import asyncio


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


class EndObserveCAD(GnirsCAD):
    async def start(self):
        print("endObserve start")

class AbortCAD(GnirsCAD):
    async def start(self):
        print("AbortCAD start")        

class ObserveCAD(GnirsCAD):
    async def start(self):
        print(f'{self.prefix} ObserveCAD start')

        self.giapi.setDataLabel(self.p.dataLabel.value)
        print(f'{self.prefix} DataLabel: {self.giapi.dataLabel}')
        
        self.giapi.observePrep()
        self.giapi.observeStartAcq()
        self.giapi.observeEndAcq()

        self.giapi.observeStartReadout()

        self.controller.startExposure(self.p.detectorTemp1.value, self.p.detectorTemp1.value, False);	
        
        self.giapi.observeEndReadout()
        self.giapi.observeStartWrite()

        print(f'{self.prefix} sync this code to the descrambling method')

        self.giapi.observeEndWrite()


class StopCAD(GnirsCAD):
    async def start(self):
        print("StopCAD start")


class GnirsCADCARController(PVGroup):

    sdsuController = controllerInterfaceDebug()

    #------ CAD commands --------
    # dc:init
    init = SubGroup(InitCAD, prefix='init.')
    initSDSU = SubGroup(InitSDSUCAD, prefix='initSDSU.')

    # dc:apply
    dcconfig = SubGroup(DCConfigCAD, prefix='dcconfig.')
    endObserve = SubGroup(EndObserveCAD, prefix='endObserve.')
    abort = SubGroup(AbortCAD, prefix='abort.')
    observe = SubGroup(ObserveCAD, prefix='observe.')
    stop = SubGroup(StopCAD, prefix='stop.')
    

    applyC = SubGroup(CARRecord, prefix='applyC.')
    apply = SubGroup(ApplyRecord, prefix='apply.')

    #------ DC configuration values --------
    lnrNum          = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="lnrNum", doc = "Low Noise Reads") 
    exposureTime    = pvproperty(value=0, dtype=caproto.ChannelType.DOUBLE, name="exposureTime", doc = "Exposure Time") 
    wcs             = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="wcs", doc = "WCS file") 
    digitalAvgs     = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="digitalAvgs", doc = "Digital Averages") 
    detBias         = pvproperty(value=1, dtype=caproto.ChannelType.DOUBLE, name="detBias", doc = "Detector Bias") 
    numcoadds       = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="numcoadds", doc = "Number of Coadds") 
    sequence        = pvproperty(value=1, dtype=caproto.ChannelType.INT, name="sequence", doc = "Sequence Count") 

    dataLabel       = pvproperty(value='GN20231011S1800', dtype=caproto.ChannelType.STRING, name="observe.A", doc = "Data Label") 


    detectorTemp1   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="detectorTemp1", doc = "Detector Temperature 1")
    detectorTemp2   = pvproperty(value=0.0, dtype=caproto.ChannelType.DOUBLE, name="detectorTemp2", doc = "Detector Temperature 2")


    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # CAD commands connect to top level CAR record
        self.dcconfig.car_record = self.applyC
        self.endObserve.car_record = self.applyC
        self.abort.car_record = self.applyC
        self.observe.car_record = self.applyC
        self.stop.car_record = self.applyC

        # Apply command connects to CAD records
        self.apply.sub_records = [self.dcconfig,self.endObserve, self.abort, self.observe, self.stop, self.init, self.initSDSU]






    

