import logging
import os
import re
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

    # TeeStream only replaces Python's sys.stdout object. The C++ extension
    # (libgnirsioc) writes with std::cout straight to file descriptor 1, never
    # touching sys.stdout, so none of its output -- including the readout's
    # pixel-count diagnostics -- reached the log. Capture at the fd level too.
    start_native_stdout_capture()

    return None


_native_capture_started = False


def start_native_stdout_capture(logger_name='native'):
    """Route writes to fd 1/2 (C/C++ stdout+stderr) into the logging system.

    Replaces fds 1 and 2 with a pipe and drains it on a daemon thread, echoing
    each line to the real terminal and logging it. Without this, anything the
    compiled extension prints is silently discarded.

    IMPORTANT: the captured lines must NOT be sent to any handler that writes
    back to fd 1/2 -- the StreamHandler on the root logger does exactly that,
    which would feed every line straight back into the pipe and loop forever.
    So this logger gets the file/custom handlers only, with propagate=False.
    """
    global _native_capture_started
    if _native_capture_started:
        return
    _native_capture_started = True

    native_logger = logging.getLogger(logger_name)
    native_logger.setLevel(logging.INFO)
    # Detach from the root logger so the console StreamHandler can't echo these
    # lines back into the captured fd (infinite loop). Re-attach only the
    # handlers that write somewhere other than fd 1/2.
    native_logger.propagate = False
    native_logger.handlers = []
    for handler in logging.getLogger().handlers:
        if isinstance(handler, StreamHandler) and not isinstance(handler, FileHandler):
            continue  # writes to the captured fd -- would loop
        native_logger.addHandler(handler)

    # Keep the original fd so captured output still reaches the console/docker logs.
    real_stdout_fd = os.dup(1)
    read_fd, write_fd = os.pipe()
    os.dup2(write_fd, 1)
    os.dup2(write_fd, 2)
    os.close(write_fd)

    # Python's own output reaches fd 1 twice over: TeeStream echoes it to the
    # real stream and the root StreamHandler prints each record. Both land in
    # this pipe, so re-logging them would duplicate every line. Those arrivals
    # are already-formatted log records, so recognise and drop them; anything
    # else on fd 1/2 is genuine native output worth capturing.
    already_logged = re.compile(
        r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3} - \S+ - (?:%s) - '
        % '|'.join(sorted(log_levels, key=len, reverse=True))
    )

    def drain():
        with os.fdopen(read_fd, 'r', buffering=1, errors='replace') as pipe:
            for line in pipe:
                line = line.rstrip('\n')
                try:
                    os.write(real_stdout_fd, (line + '\n').encode('utf-8', 'replace'))
                except OSError:
                    pass
                if line.strip() and not already_logged.match(line):
                    native_logger.irdc_debug(line)

    threading.Thread(target=drain, name='native-stdout-capture', daemon=True).start()

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
