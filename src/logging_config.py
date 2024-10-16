import logging
import os
import sys
from logging import getLogger, Formatter, StreamHandler, INFO, DEBUG, FileHandler
from logging.handlers import TimedRotatingFileHandler, QueueHandler, QueueListener
from datetime import datetime, time, timedelta
import queue
import threading
import asyncio

# Standard logging levels
# MESSAGE = 60  
# CRITICAL = 50
# ERROR = 40
# WARNING = 30
# IRDC_DEBUG = 25
# INFO = 20
# IRDC_MAX_DEBUG = 15
# DEBUG = 10
# NOTSET = 0


# Custom logging levels
IRDC_DEBUG = 25
IRDC_MAX_DEBUG = 15
PRINT = 60
LOG_MESSAGE = 70  # New level for special log messages

logging.addLevelName(IRDC_DEBUG, 'IRDC_DEBUG')
logging.addLevelName(IRDC_MAX_DEBUG, 'IRDC_MAX_DEBUG')
logging.addLevelName(PRINT, 'PRINT')
logging.addLevelName(LOG_MESSAGE, 'LOG_MESSAGE')  # Add new level name

# Mapping of log level names to numeric values
log_levels = {
    "LOG_MESSAGE": LOG_MESSAGE,  # Add new level to the mapping
    "PRINT": PRINT,
    "CRITICAL": logging.CRITICAL,
    "ERROR": logging.ERROR,
    "WARNING": logging.WARNING,
    "IRDC_DEBUG": IRDC_DEBUG,
    "INFO": logging.INFO,
    "IRDC_MAX_DEBUG": IRDC_MAX_DEBUG,
    "DEBUG": logging.DEBUG,
    "NOTSET": logging.NOTSET,
}

def irdc_debug(self, message, *args, **kws):
    if self.isEnabledFor(IRDC_DEBUG):
        self._log(IRDC_DEBUG, message, args, **kws)

def irdc_max_debug(self, message, *args, **kws):
    if self.isEnabledFor(IRDC_MAX_DEBUG):
        self._log(IRDC_MAX_DEBUG, message, args, **kws)

def log_print(self, message, *args, **kws):
    self._log(PRINT, message, args, **kws)        

def log_message(self, message, *args, **kws):
    self._log(LOG_MESSAGE, message, args, **kws)

logging.Logger.irdc_debug = irdc_debug
logging.Logger.irdc_max_debug = irdc_max_debug
logging.Logger.print = log_print
logging.Logger.log_message = log_message  # Add new method to Logger

class TeeStream:
    def __init__(self, original_stream, logger):
        self.original_stream = original_stream
        self.logger = logger

    def write(self, message):
        self.original_stream.write(message)
        message = message.strip()
        if message:
            self.logger.irdc_debug(message)

    def flush(self):
        self.original_stream.flush()

# Add this new function
def log_message_to_logger(message):
    logger = logging.getLogger('GNIRSDC')
    logger.info(message)

# Modify the CustomHandler class
class CustomHandler(logging.Handler):
    def __init__(self, loop=None):
        super().__init__()
        self.log_message_func = log_message_to_logger  # Set default function
        self.loop = loop
        self.is_emitting = False

    def set_log_message_func(self, func, loop=None):
        self.log_message_func = func
        if loop:
            self.loop = loop

    def emit(self, record):
        if self.is_emitting:
            return

        self.is_emitting = True
        try:
            if self.log_message_func:
                message = self.format(record)
                self.log_message_func(message)
        finally:
            self.is_emitting = False

# Global variable to store the custom handler
custom_handler = None

def set_custom_handler_level(level):
    global custom_handler
    if custom_handler:
        custom_handler.setLevel(level)
    else:
        print("Warning: Custom handler not set up yet. Call setup_logging first.")

def setup_logging(console_level=IRDC_DEBUG, file_level=IRDC_DEBUG, log_file=None, log_rotate_time=8, loop=None):
    global custom_handler
    root = logging.getLogger()
    root.handlers = []  # Clear existing handlers to avoid duplicate logs

    fmt_string = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"
    formatter = Formatter(fmt_string)

    stream_handler = StreamHandler()
    stream_handler.setFormatter(formatter)
    stream_handler.setLevel(console_level)
    root.addHandler(stream_handler)

    custom_handler = CustomHandler(loop=loop)  # Pass the event loop to the handler
    custom_handler.setFormatter(formatter)
    custom_handler.setLevel(console_level)
    root.addHandler(custom_handler)

    if log_file:
        log_dir = os.path.dirname(log_file)
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)

        file_handler = TimedRotatingFileHandler(log_file, when="midnight", interval=1, backupCount=7, atTime=time(log_rotate_time, 0))
        file_handler.setFormatter(formatter)
        file_handler.suffix = "%Y-%m-%d"
        root.addHandler(file_handler)

    root.setLevel(min(console_level, file_level))

    logging.getLogger('caproto').setLevel(logging.WARNING)

    stdout_logger = logging.getLogger('stdout')
    stdout_logger.setLevel(logging.INFO)

    sys.stdout = TeeStream(sys.stdout, stdout_logger)

    return None

def set_log_message_func(func, loop=None):
    global custom_handler
    if custom_handler:
        custom_handler.set_log_message_func(func, loop)
    else:
        print("Warning: Logging not set up yet. Call setup_logging first.")

if __name__ == "__main__":
    listener = setup_logging(console_level=IRDC_DEBUG, file_level=IRDC_DEBUG, log_file="example.log")
    logger = logging.getLogger('your_project')
    
    try:
        logger.error('This is an error message')
        logger.irdc_debug('This is a project-specific debug message')
        logger.info('This is an info message')
        logger.irdc_max_debug('This is a project-specific max debug message')
        logger.debug('This is a standard debug message')
        print("This is a print statement that will be captured by the logger")
        logger.log_message("This is a special log message that will be handled by log_message_func")
    finally:
        listener.stop()
