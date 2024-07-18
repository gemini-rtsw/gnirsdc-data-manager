import logging
from logging import getLogger, Formatter, StreamHandler, INFO, DEBUG, FileHandler

# Define new logging levels for project-specific debug messages
IRDC_DEBUG = 25
IRDC_MAX_DEBUG = 15

logging.addLevelName(IRDC_DEBUG, 'IRDC_DEBUG')
logging.addLevelName(IRDC_MAX_DEBUG, 'IRDC_MAX_DEBUG')

def irdc_debug(self, message, *args, **kws):
    if self.isEnabledFor(IRDC_DEBUG):
        self._log(IRDC_DEBUG, message, args, **kws)

def irdc_max_debug(self, message, *args, **kws):
    if self.isEnabledFor(IRDC_MAX_DEBUG):
        self._log(IRDC_MAX_DEBUG, message, args, **kws)

logging.Logger.irdc_debug = irdc_debug
logging.Logger.irdc_max_debug = irdc_max_debug

def setup_logging(level=INFO, log_file=None, name_on_message=False, fmt_string=None):
    """
    Common logging setup for all SysCo processes.

    :param level: Minimum logging level. Everything lower than this will
        be filtered out. Admits a string or an integer.
        See https://docs.python.org/3.8/library/logging.html#logging-level
        for details.
    :param log_file: Path to the log file. If None, logs are not written to a file.
    :param bool name_on_message: Whether to include the logger's name in the
        format string. Overridden if `fmt_string` has a value
    :param str fmt_string: Custom formatting string for our logs
    """
    root = logging.getLogger()

    if fmt_string is None:
        if name_on_message:
            fmt_string = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"
        else:
            fmt_string = "%(asctime)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"
            
    formatter = Formatter(fmt_string)

    # StreamHandler for console output
    stream_handler = StreamHandler()
    stream_handler.setFormatter(formatter)
    root.addHandler(stream_handler)

    # FileHandler for file output
    if log_file:
        file_handler = FileHandler(log_file)
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)

    root.setLevel(level)

    # Set caproto's logging level to WARNING to avoid flooding
    logging.getLogger('caproto').setLevel(logging.WARNING)

# Example usage in your project files
if __name__ == "__main__":
    setup_logging(level=IRDC_MAX_DEBUG)
    logger = logging.getLogger('your_project')
    logger.info('This is an info message')
    logger.irdc_debug('This is a project-specific debug message')
    logger.irdc_max_debug('This is a project-specific max debug message')
    logger.debug('This is a standard debug message')
    logger.error('This is an error message')
