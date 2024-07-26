#!/usr/bin/env python3

from pathlib import Path
from asyncinotify import Inotify, Mask
import asyncio

async def main_task():
    with Inotify() as inotify:
        inotify.add_watch('/tmp', Mask.CREATE | Mask.CLOSE_WRITE)
        async for event in inotify:
            print(event)
            print(repr(event.path))

loop = asyncio.get_event_loop()
try:
    loop.run_until_complete(main_task())
except KeyboardInterrupt:
    ...
finally:
    loop.run_until_complete(loop.shutdown_asyncgens())
    loop.close

