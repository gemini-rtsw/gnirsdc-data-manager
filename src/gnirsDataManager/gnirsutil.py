import configparser
import sys
import os

DEBUG_MODE = False
config_mode = 'DEFAULT'

# Create a ConfigParser object
config = configparser.ConfigParser()

config_loaded = False

def LoadConfig():
    global config_loaded

    # only need to load config once
    if config_loaded is False:
        config_loaded = True

        # Define the path to the configuration file
        config_file_path = '../../conf/gnirsdc/config.ini'

        # Read the configuration file
        config.read(config_file_path)

        # Check if the configuration file was found and read
        if os.path.exists(config_file_path) and config.sections():
            print(f"Configuration file '{config_file_path}' found and read successfully.")
        else:
            print(f"Configuration file '{config_file_path}' not found or is empty.")


        # Check for debug mode in config
        DEBUG_MODE = config.getboolean('DEFAULT', 'DEBUG_MODE', fallback=False)

        # command line will override config
        DEBUG_MODE = '--debug' in sys.argv or '-D' in sys.argv

        # Adjust configuration based on the debug value
        if DEBUG_MODE:
            config_mode = 'DEBUG'
        else:
            config_mode = 'DEFAULT'

        if DEBUG_MODE:
            print("------------ Debug mode is enabled! ------------")
        else:
            print("------------ Debug mode is disabled ------------")




