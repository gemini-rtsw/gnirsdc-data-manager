#!/bin/bash

echo "Starting Detector Controller Software"

# Check if the "gmp" container exists and remove it forcefully
if docker ps -a --format '{{.Names}}' | grep -q "^gmp$"; then
    echo "Removing the 'gmp' container..."
    docker rm -f gmp > /dev/null 2>&1
    echo "The 'gmp' container has been removed."
else
    echo "The 'gmp' container does not exist."
fi

# Run the gmp container
echo "Running the 'gmp' container..."
output=$(docker run -d --network=host --name gmp -v /readout_data:/readout_data -v /staging/perm:/staging/perm -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server)

# Check if the docker run command executed successfully
if [ $? -eq 0 ]; then
    echo "The 'gmp' container has been started successfully."
    echo "Container ID: $output"
else
    echo "Failed to start the 'gmp' container."
fi

# Check if the "gnirsdc" container exists and remove it forcefully
if docker ps -a --format '{{.Names}}' | grep -q "^gnirsdc$"; then
    echo "Removing the 'gnirsdc' container..."
    docker rm -f gnirsdc > /dev/null 2>&1
    echo "The 'gnirsdc' container has been removed."
else
    echo "The 'gnirsdc' container does not exist."
fi

# Run the gnirsdc container
echo "Running the 'gnirsdc' container..."
output=$(docker run -itd --name gnirsdc --privileged --network=host -v /readout_data:/readout_data -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run)

# Check if the docker run command executed successfully
if [ $? -eq 0 ]; then
    echo "The 'gnirsdc' container has been started successfully."
    echo "Container ID: $output"
else
    echo "Failed to start the 'gnirsdc' container."
fi