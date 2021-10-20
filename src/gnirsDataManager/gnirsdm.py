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

from gnirs_data import manager

from asyncinotify import Inotify, Mask
from caproto.server import PVGroup, template_arg_parser, pvproperty
from caproto.asyncio.server import start_server
from caproto import ChannelType

DEFAULT_PREFIX = "gnirsdm:"
DEFAULT_DATADIR = '/home/readout_data'
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
        try:
            fname = file_path.parts[-1].rpartition('.')[0]
            rpath, header = manager.decode_header(self.dp.datamov.new, fname)
            asyncio.run(self.ioc.currentLabel.write(header['PDU']['DATALABE']))
            self.dp.process_file(fname)
            asyncio.run(self.ioc.done_task(f"Done processing {file_path.parts[-1]}"))
        except Exception as exc:
            self.logger.error(f"Processing {file_path}: {exc}")

    def process_queue(self):
        self.ready.wait()
        while not self.shutting_down:
            try:
                next_task = self.queue.get(timeout=0.5)
                print(f"Processing task {next_task}")
                self.process_task(next_task)
            except queue.Empty:
                ...

    async def new_file(self, fpath):
        print(f"New file: {fpath}")
        filename = fpath.parts[-1]
        if filename.endswith('.header'):
            await self.ioc.push_task(f"Queueing new file: {filename}")
            self.queue.put(fpath)

class GnirsDataManagerIOC(PVGroup):
    state = pvproperty(
            value = StateEnum.BOOTING,
            record="mbbo"
            )

    currentLabel = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Label of image being processed"
            )

    lastError = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Last error message"
            )

    lastErrorLabel = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Last processed image label"
            )

    lastProcessed = pvproperty(
            value="",
            dtype=ChannelType.STRING,
            doc="Last processed image name"
            )

    log_array = pvproperty(
            value=[],
            max_length=MAX_LOG_SIZE,
            dtype=ChannelType.STRING,
            doc="Last log messages"
            )

    queued = pvproperty(
            value = 0,
            doc="Number of images queued for processing"
            )

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
        await asyncio.wait([self.queued.write(self.queued.value - 1),
                            self.append_log_string(log)])

async def inotify_task(ioc, proc, data_dir):
    with Inotify() as inotify:
        inotify.add_watch(data_dir, Mask.CLOSE_WRITE | Mask.MOVED_TO)
        async for event in inotify:
            print(f"{event.path}")
            print(f"Event at inotify")
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
    await create_inotify_task(ioc, proc, data_dir)
    proc.set_ready()
    await ioc.state.write(StateEnum.RUNNING)

def custom_ioc_arg_parser(*, desc, default_prefix, argv=None, macros=None,
                          supported_async_libs=None,
                          default_datadir=DEFAULT_DATADIR,
                          default_outputdir=f"{DEFAULT_DATADIR}/fits"):
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

    parser.add_argument('--data-dir', '-D', type=str, default=default_datadir,
                        help=f"Working data directory, default: {default_datadir}")
    parser.add_argument('--output-dir', '-o', type=str, default=default_outputdir,
                        help=f"FITS output directory, default: {default_outputdir}")
    args = parser.parse_args()
    ioc_options, run_options = split_args(args)
    run_options['data_dir'] = args.data_dir
    run_options['output_dir'] = args.output_dir
    return ioc_options, run_options

async def main():
    ioc_options, run_options = custom_ioc_arg_parser(
            default_prefix=DEFAULT_PREFIX,
            desc=''
            )
    ioc = GnirsDataManagerIOC(**ioc_options)
    dm = manager.DataMover(run_options['data_dir'], run_options['output_dir'])
    # TODO: "Keep should be configured via command line"
    processor = manager.DataProcessor(dm, keep=True)
    proc = GnirsDataManagerProcessor(ioc, processor)
    thrd = threading.Thread(target = proc.process_queue)
    thrd.start()
    prt = partial(startup, ioc, proc, **run_options)
    prt.__name__ = 'startup'
    try:
        await create_ioc_task(ioc.pvdb, startup_hook=prt, **run_options)
    finally:
        proc.shutdown()
        thrd.join()

def entry_point():
    try:
        return asyncio.run(main())
    except KeyboardInterrupt:
        return 0

if __name__ == '__main__':
    sys.exit(entry_point())
