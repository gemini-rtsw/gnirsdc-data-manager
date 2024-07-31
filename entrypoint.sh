#!/bin/bash
# Source environment variables
cd /gnirsdc/giapi-glue-cc
source defineGiapiglueEnv.sh

# Change to the appropriate directory
cd /gnirsdc/src

# Start DC software
python3.9 gnirsdm.py 


# Keep the container running if needed
exec "$@"
