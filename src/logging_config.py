import logging
import os
import sys
from logging import getLogger, Formatter, StreamHandler, INFO, DEBUG, FileHandler
from logging.handlers import TimedRotatingFileHandler, QueueHandler, QueueListener
from datetime import datetime, time, timedelta
import queue
import threading


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

logging.addLevelName(IRDC_DEBUG, 'IRDC_DEBUG')
logging.addLevelName(IRDC_MAX_DEBUG, 'IRDC_MAX_DEBUG')
logging.addLevelName(PRINT, 'PRINT')

# Mapping of log level names to numeric values
log_levels = {
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

logging.Logger.irdc_debug = irdc_debug
logging.Logger.irdc_max_debug = irdc_max_debug
logging.Logger.print = log_print

log_message_pv = None
log_datetime_pv = None

def set_epics_log_pvs(log_message, log_datetime):
    global log_message_pv, log_datetime_pv
    log_message_pv = log_message
    log_datetime_pv = log_datetime

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

class ThreadSafeCustomHandler(logging.Handler):
    def __init__(self, log_message_pv, log_datetime_pv):
        super().__init__()
        self.log_message_pv = log_message_pv
        self.log_datetime_pv = log_datetime_pv
        self.queue = queue.Queue()
        self.thread = threading.Thread(target=self._process_queue, daemon=True)
        self.thread.start()

    def emit(self, record):
        if record.levelno >= IRDC_DEBUG and self.log_message_pv is not None:
            self.queue.put(record)

    def _process_queue(self):
        while True:
            try:
                record = self.queue.get()
                self.log_message_pv.write(record.message)
                self.log_datetime_pv.write(record.asctime)
            except Exception:
                import traceback
                print('Error in log handler:', file=sys.stderr)
                traceback.print_exc(file=sys.stderr)

def setup_logging(console_level=IRDC_DEBUG, file_level=IRDC_DEBUG, log_file=None, log_rotate_time=8):
    root = logging.getLogger()
    root.handlers = []  # Clear existing handlers to avoid duplicate logs

    fmt_string = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"
    formatter = Formatter(fmt_string)

    log_queue = queue.Queue()
    queue_handler = QueueHandler(log_queue)
    root.addHandler(queue_handler)

    handlers = []

    stream_handler = StreamHandler()
    stream_handler.setFormatter(formatter)
    stream_handler.setLevel(console_level)
    handlers.append(stream_handler)

    custom_handler = ThreadSafeCustomHandler(log_message_pv, log_datetime_pv)
    custom_handler.setLevel(console_level)
    handlers.append(custom_handler)

    if log_file:
        log_dir = os.path.dirname(log_file)
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)

        file_handler = TimedRotatingFileHandler(log_file, when="midnight", interval=1, backupCount=7, atTime=time(log_rotate_time, 0))
        file_handler.setFormatter(formatter)
        file_handler.suffix = "%Y-%m-%d"
        handlers.append(file_handler)

    listener = QueueListener(log_queue, *handlers)
    listener.start()

    root.setLevel(min(console_level, file_level))

    logging.getLogger('caproto').setLevel(logging.WARNING)

    stdout_logger = logging.getLogger('stdout')
    stdout_logger.setLevel(logging.INFO)
    stdout_logger.addHandler(queue_handler)

    sys.stdout = TeeStream(sys.stdout, stdout_logger)

    return listener

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
    finally:
        listener.stop()