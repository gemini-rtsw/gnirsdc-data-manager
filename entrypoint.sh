#!/bin/bash
# Source environment variables
cd /gnirsdc/giapi-gluecc
source defineGiapiglueEnv.sh

# Change to the appropriate directory
cd /gnirsdc/src/gnirsDataManager

# Execute your Python script with any required arguments
mkdir -p /readout_data/log/ > /dev/null 2>&1

# Execute your Python script with any required arguments and log all output
python3.9 gnirsdm.py --data-dir /readout_data 2>&1 | tee /readout_data/log/gnirsdc-$(date +"%Y-%m-%d").log

# Keep the container running if needed
exec "$@"
