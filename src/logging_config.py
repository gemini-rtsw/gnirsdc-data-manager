import logging
import os
from logging import getLogger, Formatter, StreamHandler, INFO, DEBUG, FileHandler
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, time, timedelta


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
IRDC_DEBUG = 25  # Between INFO (20) and DEBUG (10)
IRDC_MAX_DEBUG = 15  # More detailed than DEBUG (10)
MESSAGE = 60  # Higher than CRITICAL

logging.addLevelName(IRDC_DEBUG, 'IRDC_DEBUG')
logging.addLevelName(IRDC_MAX_DEBUG, 'IRDC_MAX_DEBUG')
logging.addLevelName(MESSAGE, 'MESSAGE')

# Mapping of log level names to numeric values
log_levels = {
    "MESSAGE": MESSAGE,
    "CRITICAL": logging.CRITICAL,
    "ERROR": logging.ERROR,
    "WARNING": logging.WARNING,
    "IRDC_DEBUG": 25,
    "INFO": logging.INFO,
    "IRDC_MAX_DEBUG": 15,
    "DEBUG": logging.DEBUG,
    "NOTSET": logging.NOTSET,
}


def irdc_debug(self, message, *args, **kws):
    if self.isEnabledFor(IRDC_DEBUG):
        self._log(IRDC_DEBUG, message, args, **kws)

def irdc_max_debug(self, message, *args, **kws):
    if self.isEnabledFor(IRDC_MAX_DEBUG):
        self._log(IRDC_MAX_DEBUG, message, args, **kws)

def message(self, message, *args, **kws):
    self._log(MESSAGE, message, args, **kws)        

logging.Logger.irdc_debug = irdc_debug
logging.Logger.irdc_max_debug = irdc_max_debug
logging.Logger.message = message

def setup_logging(console_level=IRDC_DEBUG, file_level=IRDC_DEBUG, log_file=None, name_on_message=False, fmt_string=None, log_rotate_time = 8):
    """
    Common logging setup for all SysCo processes.

    :param console_level: Minimum logging level for the console. Everything lower than this will be filtered out.
    :param file_level: Minimum logging level for the log file. Everything lower than this will be filtered out.
    :param log_file: Path to the log file. If None, logs are not written to a file.
    :param bool name_on_message: Whether to include the logger's name in the format string. Overridden if `fmt_string` has a value.
    :param str fmt_string: Custom formatting string for our logs.
    """
    root = logging.getLogger()
    root.handlers = []  # Clear existing handlers to avoid duplicate logs

    if fmt_string is None:
        if name_on_message:
            fmt_string = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"
        else:
            fmt_string = "%(asctime)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"
            
    formatter = Formatter(fmt_string)

    # StreamHandler for console output
    stream_handler = StreamHandler()
    stream_handler.setFormatter(formatter)
    stream_handler.setLevel(console_level)
    root.addHandler(stream_handler)

    # FileHandler for file output
    if log_file:
        # Ensure the log directory exists
        log_dir = os.path.dirname(log_file)
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)

        handler = TimedRotatingFileHandler(log_file, when="midnight", interval=1, backupCount=7, atTime=time(log_rotate_time, 0))
        handler.setFormatter(formatter)
        handler.suffix = "%Y-%m-%d"
        root.addHandler(handler)


    root.setLevel(file_level)

    # Set caproto's logging level to WARNING to avoid flooding
    logging.getLogger('caproto').setLevel(logging.WARNING)

# Example usage in your project files
if __name__ == "__main__":
#    setup_logging(level=IRDC_MAX_DEBUG)
    setup_logging(level=logging.ERROR)
    setup_logging(level=DEBUG, log_file='/logs/gnirsdc.log')
    logger = logging.getLogger('your_project')
    logger.error('This is an error message')
    logger.irdc_debug('This is a project-specific debug message')
    logger.info('This is an info message')
    logger.irdc_max_debug('This is a project-specific max debug message')
    logger.debug('This is a standard debug message')
