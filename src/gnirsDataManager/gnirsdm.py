#!/usr/bin/env python3

import asyncio
import enum
import importlib
import os
import queue
import sys
import threading
import time
from concurrent import futures
from functools import partial
from pathlib import Path
from logging import getLogger

from gemUtilities import checkCAConnection
from diskSpaceMonitor import DiskSpacePVGroup


#from gnirs_data import manager

import manager

from asyncinotify import Inotify, Mask
from caproto.server import PVGroup, template_arg_parser, pvproperty, SubGroup, ioc_arg_parser, run
from caproto.asyncio.server import start_server
from caproto import ChannelType
from caproto.sync.client import read

from datetime import datetime



import gnirssdsu
from gnirssdsu import GnirsCADCARController

from gnirssdsu import DebugMode

import gnirsgiapi
from gnirsgiapi import GiapiInterface

INSTRUMENT_NAME = "GNIRS"
DEFAULT_PREFIX = "gnirsdm:"
DEFAULT_DATADIR = '/readout_data'
MAX_LOG_SIZE = 5



async def wait_for(*awaitables):
    loop = asyncio.get_event_loop()
    await asyncio.wait(tuple(loop.create_task(aw) for aw in awaitables))

class StateEnum(enum.IntEnum):
    BOOTING = 0,
    INITIALIZING = 1,
    RUNNING = 2,
    PROCESSING = 3

class GnirsDataManagerProcessor:
    def __init__(self, ioc, processor):
        self.ioc = ioc
        self.dp = processor
        self.queue = queue.Queue()
        self.ready = threading.Event()
        self.shutting_down = False
        self.logger = getLogger('GnirsDataManagerProcessor')

    def set_ready(self):
        self.ready.set()

    def shutdown(self):
        self.shutting_down = True

    def process_task(self, file_path):
        fname = file_path.parts[-1].rpartition('.')[0]
        label = None
        try:
            rpath, header = manager.decode_header(self.dp.datamov.new, fname)
            label = header['PDU']['DATALABE']
            asyncio.run(self.ioc.currentLabel.write(label))
            self.dp.process_file(fname)
        except Exception as exc:
            self.logger.error(f"Processing {file_path}: {exc}")
            if label is None:
                asyncio.run(self.set_error(fname, "Illegal header"))
            else:
                asyncio.run(self.set_error(label, str(exc)))
        finally:
            asyncio.run(self.ioc.done_task(f"Done processing {file_path.parts[-1]}"))


    def process_queue(self):
        '''Process tasks from the queue.

        This method continuously processes tasks from the queue. It repeatedly checks 
        for tasks, with a brief wait (timeout of 0.5 seconds) between checks. If a task 
        is found, it is processed, and the system's state and current label are updated.
        If the queue is empty, it catches the 'queue.Empty' exception, allowing the loop 
        to continue checking for new tasks. This process continues unless the system is 
        shutting down.
        '''

        self.ready.wait()
        while not self.shutting_down:
            try:
                next_task = self.queue.get(timeout=0.5)
                asyncio.run(self.ioc.state.write(StateEnum.PROCESSING))
                self.process_task(next_task)
                asyncio.run(self.ioc.currentLabel.write(''))
                asyncio.run(self.ioc.state.write(StateEnum.RUNNING))
            except queue.Empty:
                ...

    async def set_error(self, label, message):
        await self.ioc.lastErrorLabel.write(label)
        await self.ioc.lastError.write(message)

    async def new_file(self, fpath):
        '''Queue a new file for processing.

        This asynchronous method checks if the provided file path ends with '.header'.
        If it does, the file is considered for queuing. It logs the action of queuing 
        the new file and then adds the file path to the processing queue. This method 
        is designed to handle '.header' files specifically.
        
        Args:
        fpath (Path): The file path of the file to be queued.
        '''
        filename = fpath.parts[-1]
        if filename.endswith('.header'):
            await self.ioc.push_task(f"Queueing new file: {filename}")
            self.queue.put(fpath)

class GnirsDataManagerIOC(PVGroup):

         

    def __init__(self, *args, **kwargs):

        super().__init__(*args, **kwargs)

        self.processor = None 

        print(f'{self.CADInterface.apply.prefix} Apply sub recs: {len(self.CADInterface.apply.sub_records)}')



    CADInterface = SubGroup(GnirsCADCARController, prefix="")
    GIAPIInterface = GiapiInterface()
    DiskSpaceMonitor = SubGroup(DiskSpacePVGroup, prefix="")


#-----------------------------------------------------------------------------
    uptime = pvproperty(value=0, dtype=int)

    @uptime.startup
    async def uptime(self, instance, async_lib):
        while True:
            await instance.write(instance.value + 1) # Increment the uptime counter
            await async_lib.library.sleep(1.0)


#-----------------------------------------------------------------------------
    health = pvproperty(value=0, dtype=ChannelType.STRING)

    @health.startup
    async def health(self, instance, async_lib):
            await instance.write("GOOD")

    async def set_health(self, value):
        await self.health.write(value)

#-----------------------------------------------------------------------------
    heartbeat = pvproperty(value=0, dtype=int)

    @heartbeat.startup
    async def heartbeat(self, instance, async_lib):
        while True:
            if instance.value == 0:
                await instance.write(1)
            else:
                await instance.write(0)
            await instance.write(instance.value)
            await async_lib.library.sleep(0.5)

#-----------------------------------------------------------------------------
    tcs_connection = pvproperty(value=0, dtype = ChannelType.STRING) 

    @tcs_connection.startup
    async def tcs_connection(self, instance, async_lib):
        while True:
            connected = checkCAConnection("tcs:ak:astCtx", 1.0)

            await instance.write("CONNECTED" if connected else "DISCONNECTED")
            await async_lib.library.sleep(1)  # check every second        

            if not connected:
                await self.set_health("BAD")
                await self.logMessage("TCS disconnected")
            else:
                await self.set_health("GOOD")
                await self.logMessage("TCS connected")


#-----------------------------------------------------------------------------
    log_message = pvproperty( value = "", dtype=ChannelType.STRING, doc="Record the last log message" )
    log_datetime = pvproperty( value = "", dtype=ChannelType.STRING, doc="Record the last log date" )


    async def logMessage(self, message):
        if self.log_message.value != message:
            await self.log_datetime.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")  # Create a timestamp
            await self.log_message.write(message)
            print(message)

#-----------------------------------------------------------------------------
    archive_fits = pvproperty(value=1, dtype = ChannelType.INT) 

#-----------------------------------------------------------------------------
    data_dir = pvproperty(value=1, dtype = ChannelType.STRING) 

#-----------------------------------------------------------------------------
    state = pvproperty(
            value = StateEnum.BOOTING,
            record="mbbo"
            )

    @pvproperty(dtype=ChannelType.STRING, doc="Name of the instrument")
    async def instrument(self, instance):
        return INSTRUMENT_NAME

#-----------------------------------------------------------------------------
    currentLabel = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Label of image being processed"
            )

#-----------------------------------------------------------------------------
    lastError = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Last error message"
            )

#-----------------------------------------------------------------------------
    lastErrorLabel = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Last processed image label with errors"
            )

#-----------------------------------------------------------------------------
    lastProcessed = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Last processed image name"
            )

#-----------------------------------------------------------------------------
    log_array = pvproperty(
            value=[],
            max_length=MAX_LOG_SIZE,
            dtype=ChannelType.STRING,
            doc="Last log messages"
            )

#-----------------------------------------------------------------------------
    queued = pvproperty(
            value = 0,
            doc="Number of images queued for processing"
            )
    
#-----------------------------------------------------------------------------
    include_eng = pvproperty(value=0, dtype = ChannelType.INT, doc="Include engineering images in fits")

#-----------------------------------------------------------------------------
        
    restart_ioc = pvproperty(value=0)

    @restart_ioc.putter
    async def restart_ioc(self, instance, value):
        if value == 1:
            # Logic to stop the current IOC
            self._context.stop()
            # New logic to restart the IOC
            await restart()

#-----------------------------------------------------------------------------


    def start_ioc():
        ioc = SimpleIOC(**self.ioc_options)
        run(ioc.pvdb, **self.run_options)


    async def push_task(self, log):
        await wait_for(self.queued.write(self.queued.value + 1),
                       self.append_log_string(log))

    async def append_log_string(self, string):
        current = self.log_array.value
        while len(current) >= MAX_LOG_SIZE:
            current = current[1:]
        current.append(string)
        await self.log_array.write(current)

    async def done_task(self, log):
        await wait_for(self.queued.write(self.queued.value - 1),
                       self.append_log_string(log))

async def inotify_task(ioc, proc, data_dir):
    '''
    Asynchronously monitor a directory for new files.

    This function sets up an inotify watch on the specified data directory. It
    listens for file creation and move events. When such an event occurs, the 
    function processes the new file by calling `proc.new_file` with the path 
    of the new or moved file.
    
    Args:
    ioc: The IO Controller used in the monitoring process.
    proc: The processor object responsible for handling new files.
    data_dir: The directory to monitor for file events.
    '''
   
    os.makedirs(data_dir, exist_ok=True)  # Create the directory if it doesn't exist
    print(data_dir) 

    with Inotify() as inotify:
        inotify.add_watch(data_dir, Mask.CLOSE_WRITE | Mask.MOVED_TO)
        async for event in inotify:
            await proc.new_file(event.path)

async def create_inotify_task(ioc, proc, data_dir, **kw):
    return asyncio.create_task(inotify_task(ioc, proc, f"{data_dir}/new"), name="inotify_task")

async def create_ioc_task(pvdb, *, module_name="caproto.asyncio.server",
        interfaces=None, log_pv_names=False, startup_hook=None, **kw):
    """
    Create an IOC awaitable, given its PV database dictionary.

    Parameters
    ----------
    pvdb : dict
        The PV database.

    interfaces : list, optional
        List of interfaces to listen on.

    log_pv_names : bool, optional
        Log PV names at startup.

    startup_hook : coroutine, optional
        Hook to call at startup with the ``async_lib`` shim.

    Returns
    -------
    The awaitable that will execute the IOC
    """
    module = importlib.import_module(module_name)
    return await module.start_server(pvdb, interfaces=interfaces,
            log_pv_names=log_pv_names, startup_hook=startup_hook)

async def startup(ioc, proc, async_lib, *, data_dir, **kw):
    await ioc.state.write(StateEnum.INITIALIZING)
    print(data_dir)
    await create_inotify_task(ioc, proc, data_dir)
    proc.set_ready()
    await ioc.state.write(StateEnum.RUNNING)


def custom_ioc_arg_parser(*, desc, default_prefix, argv=None, macros=None,
                          supported_async_libs=None):
    """
    Custom ArgumentParser for the Gemini NIRS Data Manager IOC.

    Parameters
    ----------
    description : string
        Human-friendly description of what that IOC does
    default_prefix : string
    args : list, optional
        Defaults to sys.argv
    macros : dict, optional
        Maps macro names to default value (string) or None (indicating that
        this macro parameter is required).
    supported_async_libs : list, optional
        "White list" of supported server implementations. The first one will
        be the default. If None specified, the parser will accept all of the
        (hard-coded) choices.

    Returns
    -------
    ioc_options : dict
        kwargs to be handed into the IOC init.

    run_options : dict
        kwargs to be handed to run
    """
    parser, split_args = template_arg_parser(desc=desc, default_prefix=default_prefix,
                                             argv=argv, macros=macros,
                                             supported_async_libs=supported_async_libs)

    parser.add_argument('--data-dir', '-d', type=str, 
                        help="Working data directory,")
    parser.add_argument('--output-dir', '-o', type=str,
                        help="FITS output directory, default: {data-dir}/fits")
    parser.add_argument('--top', '-t', type=str,
                        help="EPICS top name")
    parser.add_argument('--debug', '-D', action='store_true', 
                        help="Set Debug mode - no SDSU")    
#    parser.add_argument('--list-pvs', action='store_true', help='List Process Variables')
    args = parser.parse_args()
    ioc_options, run_options = split_args(args)
    run_options['data_dir'] = args.data_dir
    run_options['output_dir'] = f'{args.data_dir}/fits' if args.output_dir is None else args.output_dir
    run_options['debug'] = args.debug


    if (args.top is not None):
        ioc_options["prefix"] = args.top + ":"
        print(f"Top name: {ioc_options['prefix']}")

    if (args.debug == True):
        DebugMode(True)
        print (f"Debug mode: True")
    else:
        DebugMode(False)
        print (f"Debug mode: False")

    return ioc_options, run_options



async def main():
    ioc_options, run_options = custom_ioc_arg_parser(
            default_prefix=DEFAULT_PREFIX,
            desc=''
            )
    print ("create IOC")
    ioc = GnirsDataManagerIOC(**ioc_options)
    print ("IOC created")
    await ioc.data_dir.write(run_options['data_dir'])




    dm = manager.DataMover(run_options['data_dir'], run_options['output_dir'])
    # TODO: "Keep should be configured via command line"
    ioc.processor = manager.DataProcessor(dm, keep=True)
    proc = GnirsDataManagerProcessor(ioc, ioc.processor)
    thrd = threading.Thread(target = proc.process_queue)
    thrd.start()
    prt = partial(startup, ioc, proc, **run_options)
    prt.__name__ = 'startup'
    try:
        server_context = await create_ioc_task(ioc.pvdb, startup_hook=prt, **run_options)
    finally:
        proc.shutdown()
        thrd.join()

async def shutdown(proc, thrd):
    """Shut down the IOC components."""
    proc.shutdown()
    thrd.join()

async def restart():
    """Restart the IOC by shutting down and then starting again."""
    # Extract existing IOC components (e.g., proc, thrd) here, if needed
    await shutdown(proc, thrd)
    await main()

def entry_point():
    try:
        return asyncio.run(main())
    except KeyboardInterrupt:
        return 0

def restart_entry_point():
    try:
        return asyncio.run(restart())
    except KeyboardInterrupt:
        return 0

if __name__ == '__main__':
    sys.exit(entry_point())

    '''
def entry_point():
    try:
        return asyncio.run(main())
    except KeyboardInterrupt:
        return 0

if __name__ == '__main__':
    sys.exit(entry_point())
    '''
