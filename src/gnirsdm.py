#!/usr/bin/env python3

import asyncio
import enum
import importlib
import os
import subprocess
import queue
import sys
import threading
import time

# Add these lines at the beginning of the script
import os
import sys

# Change the current working directory to the script's directory
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

# Update the Python path to include the script's directory
sys.path.insert(0, script_dir)

from concurrent import futures
from functools import partial
from pathlib import Path
from gemUtilities import checkCAConnection
from diskSpaceMonitor import DiskSpacePVGroup

from multiprocessing import Process

import manager

from asyncinotify import Inotify, Mask
from caproto.server import PVGroup, template_arg_parser, pvproperty, SubGroup, ioc_arg_parser, run
from caproto.asyncio.server import start_server
from caproto import ChannelType
from caproto.sync.client import read

from datetime import datetime

from enum import Enum

import multiprocessing as mp

from gnirssdsu import GnirsCADCARController

from gnirsgiapi import GiapiInterface, check_gmp_and_exit, check_gmp

from gnirsutil import config, config_mode, DEBUG_MODE

from logging import getLogger
from logging_config import set_log_message_func, set_custom_handler_level, IRDC_DEBUG, log_levels

WORKING_DIR = os.getcwd()
os.environ['EPICS_CA_ADDR_LIST'] = config[config_mode].get('EPICS_CA_ADDR_LIST')

print(f"Working Directory: {WORKING_DIR}")


# Access the configuration values
INSTRUMENT_NAME = config[config_mode].get('INSTRUMENT_NAME')
DEFAULT_PREFIX = config[config_mode].get('DEFAULT_PREFIX') + ":"
DEFAULT_DATADIR = config[config_mode].get('DEFAULT_DATADIR')
MAX_LOG_SIZE = config[config_mode].getint('MAX_LOG_SIZE')
GMP_HOST = config[config_mode].get('GMP_HOST')
GMP_PORT = config[config_mode].getint('GMP_PORT')
GMP_TEST_PORT = config[config_mode].getint('GMP_TEST_PORT')


logger = getLogger('GNIRSDC')


logger.print("""
      _____  _   _ _____ _____   _____   _____   _____ 
     / ____|| \ | |_   _|  __ \ / ____| |  __ \ / ____|
    | |  __ |  \| | | | | |__) | (___   | |  | | |     
    | | |_ ||     | | | |  _  / \___ \  | |  | | |     
    | |__| || |\  |_| |_| | \ \ ____) | | |__| | |____ 
     \_____||_| \_|_____|_|  \_\_____/  |_____/ \_____|
""")

logger.print("")
logger.print("Booting...")

logger.print(f"EPICS top: {DEFAULT_PREFIX}")
# Perform GMP check
check_gmp_and_exit(GMP_HOST, GMP_TEST_PORT)
logger.print("GMP check passed. Continuing with initialization...")


def get_repo_info_for_directories():

    # List of directory names
    directories = [
        "/gnirsdc",
        "/pycadcar",
        "/gnirsdc-lib"
    ]


    # Function to get the commit hash, branch, remote origin, and last commit message for a repository
    def get_repo_info(directory):
        try:
            # Change to the repository directory
            os.chdir(directory)

            # Run git commands to get the commit hash, branch, remote origin, and last commit message
            commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode("utf-8").strip()
            branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).decode("utf-8").strip()
            remote_origin = subprocess.check_output(["git", "config", "--get", "remote.origin.url"]).decode("utf-8").strip()
            last_commit_message = subprocess.check_output(["git", "log", "-1", "--pretty=%B"]).decode("utf-8").strip()

            # Drop everything except the "gitlab.com" part from the remote origin URL
            remote_origin = remote_origin.split("@")[1]

            return commit_hash, branch, remote_origin, last_commit_message
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None, None, None, None

    # Iterate over the directories and print the repo information
    for directory in directories:
        commit_hash, branch, remote_origin, last_commit_message = get_repo_info(directory)
        if commit_hash and branch and remote_origin:
            logger.print(f"Repo: {directory}")
            logger.print(f"Commit Hash: {commit_hash}")

            # use env variable to pass dc and lib commit hash to fits header
            if (directory == '/gnirsdc'):
                os.environ['DC_COMMIT'] = commit_hash

            if (directory == '/gnirsdc-lib'):
                os.environ['LIB_COMMIT'] = commit_hash

            logger.print(f"Branch: {branch}")
            logger.print(f"Remote Origin: {remote_origin}")
            logger.print(f"Last Commit Message: {last_commit_message}")
            logger.print("---")
        else:
            logger.print(f"Repo: {directory}")
            logger.print("Failed to retrieve repo information.")
            logger.print("---")


    os.chdir(WORKING_DIR)




async def wait_for(*awaitables):
    loop = asyncio.get_event_loop()
    await asyncio.wait(tuple(loop.create_task(aw) for aw in awaitables))

class StateEnum(enum.IntEnum):
    BOOTING = 0,
    INITIALIZING = 1,
    RUNNING = 2,
    PROCESSING = 3

class Command(Enum):
    OBSERVE_START_WRITE = 1
    OBSERVE_END_WRITE = 2



def parent_process_commands(pipe, ioc):
    while True:
        command, label = pipe.recv()
        if command == Command.OBSERVE_START_WRITE:

            asyncio.run(ioc.currentLabel.write(label))
            ioc.GIAPIInterface.observeStartWrite(label)

        elif command == Command.OBSERVE_END_WRITE:

            ioc.GIAPIInterface.observeEndWrite(label)

        elif command is None:
            break


def standalone_process_task(file_path, dp, pipe):
    fname = file_path.parts[-1].rpartition('.')[0]
    label = None

    # Decode header
    try:
        rpath, header = manager.decode_header(dp.datamov.new, fname)
        label = header['PDU']['LABEL']
    except Exception as exc:
        print(f"Error reading raw header file: {fname}")
        print(f"Exception: {exc}")
        return

    print(f'GDS writing fits')
    pipe.send((Command.OBSERVE_START_WRITE, label))

    # Process file
    try:
        dp.process_file(fname, os.getenv('DC_COMMIT', 'dc_commit_missing'), os.getenv('LIB_COMMIT', 'lib_commit_missing'))
    except Exception as exc:
         print(f"Error processing file {fname}: {exc}")
        
    pipe.send((Command.OBSERVE_END_WRITE, label))

#    finally:
#        try:
#            asyncio.run(ioc.done_task(f"Done processing {file_path.parts[-1]}"))
#        except Exception as async_exc:
#            logger.irdc_debug(f"Error in done_task: {async_exc}")

class GnirsDataManagerProcessor:
    def __init__(self, ioc, processor):

        self.ioc = ioc
        self.dp = processor
        self.queue = queue.Queue()
        self.ready = threading.Event()
        self.shutting_down = False
        self.logger = getLogger('GNIRSDC')

        self.processes = []

        self.parent_conn, self.child_conn = mp.Pipe()
        self.command_thread = threading.Thread(target=parent_process_commands, args=(self.parent_conn, self.ioc))
        self.command_thread.start()

    def set_ready(self):
        self.ready.set()

    def shutdown(self):
        self.shutting_down = True

        self.parent_conn.send((None, None))  # Signal to stop the command thread
        self.command_thread.join()

        for p in self.processes:
            p.join()

    def process_queue(self):
        self.ready.wait()
        while not self.shutting_down:
            try:
                next_task = self.queue.get(timeout=0.5)
                asyncio.run(self.ioc.state.write(StateEnum.PROCESSING))
                p = mp.Process(target=standalone_process_task, args=(next_task, self.dp, self.child_conn))
                p.start()
                self.processes.append(p)
                asyncio.run(self.ioc.currentLabel.write(''))
                asyncio.run(self.ioc.state.write(StateEnum.RUNNING))
            except queue.Empty:
                continue  # Continue checking for new tasks
            self.cleanup_processes()

    def cleanup_processes(self):
        # Clean up completed processes
        for p in list(self.processes):
            if not p.is_alive():
                p.join()  # Ensure the process has ended cleanly
                self.processes.remove(p)

    async def set_error(self, label, message):
        await self.ioc.lastErrorLabel.write(label)
        await self.ioc.lastError.write(message)

    async def new_file(self, fpath):
        filename = fpath.parts[-1]
        if filename.endswith('.header'):
            await self.ioc.push_task(f"Queueing new file: {filename}")
            self.queue.put(fpath)



class GnirsDataManagerIOC(PVGroup):


    def __init__(self, *args, **kwargs):
        
        super().__init__(*args, **kwargs)

        self.processor = None 

        print(f'{self.CADInterface.apply.prefix} Apply sub recs: {len(self.CADInterface.apply.cads.records)}')



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
    tcs_connection = pvproperty(value=0, dtype=ChannelType.STRING)

    @tcs_connection.startup
    async def tcs_connection(self, instance, async_lib):
        loop = asyncio.get_event_loop()

        def check_tcs_connection(loop):
            while True:
                # Use 'tc:' instead of 'tcs:' if in debug mode
                pv_name = "tc:heartbeat" if DEBUG_MODE else "tcs:heartbeat"
                connected = checkCAConnection(pv_name, 1.0)
                asyncio.run_coroutine_threadsafe(
                    self.update_tcs_connection(instance, connected), 
                    loop
                )
                time.sleep(1)  # check every second

        threading.Thread(target=check_tcs_connection, args=(loop,), daemon=True).start()

    async def update_tcs_connection(self, instance, connected):
        await instance.write("CONNECTED" if connected else "DISCONNECTED")
        if not connected:
            await self.set_health("BAD")
            await self.logMessage("TCS disconnected")
        else:
            await self.set_health("GOOD")

#-----------------------------------------------------------------------------
    log_message = pvproperty(value="", dtype=ChannelType.STRING, doc="Record the last log message")
    log_datetime = pvproperty(value="", dtype=ChannelType.STRING, doc="Record the last log date")

    @log_message.startup
    async def log_message(self, instance, async_lib):
        set_log_message_func(self.logMessage, loop=asyncio.get_event_loop())

    async def logMessage(self, message):
        if self.log_message.value != message:
            await self.log_datetime.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            await self.log_message.write(message)

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
    
#-------------- GMP status -------------------

    gmp_status = pvproperty(value=0.0, read_only=True, dtype=ChannelType.STRING, name="gmp_status")

    @gmp_status.scan(period=5)  # Scan every 5 seconds
    async def gmp_status(self, instance, async_lib):
        try:
            check_gmp()
            await instance.write("CONNECTED")
        except Exception as e:
            await instance.write("DISCONNECTED")
        

#-----------------------------------------------------------------------------
    wcs_file = pvproperty(
        value="None",
        dtype=ChannelType.STRING,
        doc="Name of the WCS file"
    )

    @wcs_file.putter
    async def wcs_file(self, instance, value):
        # This method will be called whenever the WCS file is updated
        await self.logMessage(f"WCS file: {value}")

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
    log_level = pvproperty(
        value=0,
        dtype=ChannelType.ENUM,
        enum_strings=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
        doc="Set the log level"
    )

    @log_level.putter
    async def log_level(self, instance, value):
        level_map = {
            0: log_levels.DEBUG,
            1: log_levels.INFO,
            2: log_levels.WARNING,
            3: log_levels.ERROR,
            4: log_levels.CRITICAL
        }
        new_level = level_map.get(value, log_levels.INFO)
        set_custom_handler_level(new_level)
        await self.logMessage(f"Log level changed to {instance.enum_strings[value]}")
        return value

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
    '''
    #uncomment for CC debug channels

    cc1       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:apply.DIR", doc = "")
    cc2       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:apply.VAL", doc = "")
    cc3       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:apply.MESS", doc = "") 
    cc4       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:applyC.CLID", doc = "") 
    cc5       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:applyC.VAL", doc = "") 
    cc6       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:applyC.OMSS", doc = "") 
    cc7       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:coverPosCad.B", doc = "") 
    cc8       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:fw1PosCad.B", doc = "") 
    cc9       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:focusStepsCad.A", doc = "") 
    cc10       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:gratingPosCad.E", doc = "") 
    cc11       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:xdispPosCad.B", doc = "") 
    cc12       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:acqPosCad.B", doc = "") 
    cc13       = pvproperty(value=1, dtype=ChannelType.LONG, name="focus:focusbest", doc = "") 
    cc14       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:gratingPosCad.C", doc = "") 
    cc15       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:cameraPosCad.B", doc = "") 
    cc16       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:gratingPosCad.A", doc = "") 
    cc17       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:gratingPosCad.D", doc = "") 
    cc19       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:slitPosCad.B", doc = "") 
    cc20       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:deckerPosCad.B", doc = "") 
    cc21       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:fw2PosCad.B", doc = "") 
    cc22       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:xdispPosition", doc = "") 
    cc23       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:focusPosition", doc = "") 
    cc24       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:slitPosition", doc = "") 
    cc25       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:acqPosition", doc = "") 
    cc26       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:coverPosition", doc = "") 
    cc27       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:gratingPosition", doc = "") 
    cc28       = pvproperty(value=1, dtype=ChannelType.LONG, name="cc:gratingPosCad.B", doc = "") 
    cc29       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:fw2Position", doc = "") 
    cc30       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:fw1Position", doc = "") 
    cc31       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:cameraPosition", doc = "") 
    cc32       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:deckerPosition", doc = "") 
    cc33       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:gratingWvlength.VAL", doc = "") 
    cc34       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:deckerEng", doc = "") 
    cc35       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:fw2Eng", doc = "") 
    cc36       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:gratingEng", doc = "") 
    cc37       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:cameraEng", doc = "") 
    cc38       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:fw1Eng", doc = "") 
    cc39       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:slitEng", doc = "") 
    cc40       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:xdispEng", doc = "") 
    cc41       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:focusEng", doc = "") 
    cc42       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:gratingTilt", doc = "") 
    cc43       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:gratingOrder", doc = "") 
    cc44       = pvproperty(value=1, dtype=ChannelType.LONG, name="sad:cc:name", doc = "") 
    '''

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
    os.makedirs(data_dir, exist_ok=True)
    print(f"Monitoring directory: {data_dir}")

    for filename in os.listdir(data_dir):
        file_path = Path(data_dir) / filename
        if file_path.is_file():
            await proc.new_file(file_path)

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

    parser.add_argument('--data-dir', '-d', type=str, help="Working data directory,", default=DEFAULT_DATADIR)
    parser.add_argument('--output-dir', '-o', type=str, help="FITS output directory, default: {data-dir}/fits")
    parser.add_argument('--top', '-t', type=str, help="EPICS top name")
    parser.add_argument('--debug', '-D', action='store_true', help="Set Debug mode - no SDSU")
    
    # debug mode is here so it shows up in help, but it is manually checked at config read to allow override of config file

#    parser.add_argument('--list-pvs', action='store_true', help='List Process Variables')
    args = parser.parse_args()
    ioc_options, run_options = split_args(args)
    run_options['data_dir'] = args.data_dir
    run_options['output_dir'] = f'{args.data_dir}/fits' if args.output_dir is None else args.output_dir
    run_options['debug'] = args.debug


    if (args.top is not None):
        ioc_options["prefix"] = args.top + ":"
        print(f"Top name: {ioc_options['prefix']}")

#    if (args.debug == True or DEBUG_MODE == True):
#        DebugMode(True)
#        print (f"Debug mode: True")
#    else:
#        DebugMode(False)
#        print (f"Debug mode: False")

    return ioc_options, run_options



# Global variable to store the main event loop
main_event_loop = None

async def main():
    global main_event_loop
    main_event_loop = asyncio.get_event_loop()
    
    # Call the function to get repo info for the specified directories
    get_repo_info_for_directories()

    ioc_options, run_options = custom_ioc_arg_parser(
            default_prefix=DEFAULT_PREFIX,
            desc='Gemini NIRS Data Manager IOC'
            )
    

    print ("create IOC")
    ioc = GnirsDataManagerIOC(**ioc_options)


    print ("IOC created")
    await ioc.data_dir.write(run_options['data_dir'])


    print(f"Working directory: {os.getcwd()}")


    dm = manager.DataMover(run_options['data_dir'], run_options['output_dir'])
    # TODO: "Keep should be configured via command line"
    ioc.processor = manager.DataProcessor(dm)
    proc = GnirsDataManagerProcessor(ioc, ioc.processor)
    thrd = threading.Thread(target = proc.process_queue)
    thrd.start()
    prt = partial(startup, ioc, proc, **run_options)
    prt.__name__ = 'startup'
    try:
        server_context = await create_ioc_task(ioc.pvdb, 
                                               startup_hook=prt, 
                                               tcp_port=5064,  # Standard EPICS TCP port
                                               udp_port=5065,  # Standard EPICS UDP port
                                               **run_options)
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

