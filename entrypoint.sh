#!/bin/bash

# Source environment variables
cd /gnirsdc/giapi-glue-cc
source defineGiapiglueEnv.sh

# Change to the appropriate directory
cd /gnirsdc/src

# Default argument for the Python script
ARGS="--top nirs"

# Check if any arguments are passed to the script
if [ $# -ne 0 ]; then
    ARGS="$@"
fi

# Start the system monitor in the background
python3.9 system_manager_server.py &

# Start DC software with the arguments
python3.9 gnirsdm.py $ARGS

# Keep the container running if needed
exec "$@"
