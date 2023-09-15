import caproto
from caproto.server import pvproperty, SubGroup, PVGroup, ioc_arg_parser, run
from pygeminirec.applyrecord import ApplyRecord
from pygeminirec.cadrecord import CADRecord
from pygeminirec.carrecord import CARRecord
import asyncio


from libgnirsioc import controllerInterface
from libgnirsioc import controllerInterfaceDebug


class InitCAD(CADRecord):
    async def start(self):
        print("InitCAD start")
        self.parent.sdsuController.init()


class DCConfigCAD(CADRecord):
    async def start(self):
        controller  = self.parent.sdsuController 
        p           = self.parent

        print(f'{self.prefix} START DC Config')
        controller.setExposure(p.lnrNum.value, p.digitalAvgs.value, p.exposureTime.value, p.sequence.value)


class EndObserveCAD(CADRecord):
    async def start(self):
        print("endObserve start")

class AbortCAD(CADRecord):
    async def start(self):
        print("AbortCAD start")        

class ObserveCAD(CADRecord):
    async def start(self):
        print("ObserveCAD start")

class StopCAD(CADRecord):
    async def start(self):
        print("StopCAD start")


class GnirsSDSUController(PVGroup):

    sdsuController = controllerInterfaceDebug()

    #------ CAD commands --------
    # dc:init
    dcInit = SubGroup(InitCAD, prefix='initSDSU.')

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

    observeLabel    = pvproperty(value='', dtype=caproto.ChannelType.STRING, name="observe.A", doc = "Data Label") 


    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # CAD commands connect to top level CAR record
        self.dcconfig.car_record = self.applyC
        self.endObserve.car_record = self.applyC
        self.abort.car_record = self.applyC
        self.observe.car_record = self.applyC
        self.stop.car_record = self.applyC

        # Apply command connects to CAD records
        self.apply.sub_records = [self.dcconfig,self.endObserve, self.abort, self.observe, self.stop]






    

