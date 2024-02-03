#!/bin/bash
# Source environment variables
cd /gnirsdc/giapi-gluecc
source defineGiapiglueEnv.sh

# Change to the appropriate directory
cd /gnirsdc/src/gnirsDataManager

# Execute your Python script with any required arguments
python3.9 gnirsdm.py --data-dir /readout_data

# Keep the container running if needed
exec "$@"