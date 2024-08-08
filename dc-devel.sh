#!/bin/bash

# This script starts Docker containers for the Detector Controller Software in a development environment.
# It first tries to start the 'gmp' and 'gnirsdc' containers using development images.
# If either of them fails to start, it runs 'dc-devel.sh' and attempts to start the containers again.

echo "Starting Detector Controller Software"

# Function to start a Docker container
start_container() {
    container_name=$1
    image_name=$2

    # Check if the container exists and remove it forcefully
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "Removing the '${container_name}' container..."
        docker rm -f ${container_name} > /dev/null 2>&1
        echo "The '${container_name}' container has been removed."
    else
        echo "The '${container_name}' container does not exist."
    fi

    # Run the container
    echo "Running the '${container_name}' container..."
    output=$(docker run -d --network=host --privileged --name ${container_name} -v /readout_data:/readout_data -v /staging/perm:/staging/perm -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro ${image_name})

    # Check if the docker run command executed successfully
    if [ $? -eq 0 ]; then
        echo "The '${container_name}' container has been started successfully."
        echo "Container ID: $output"
        return 0
    else
        echo "Failed to start the '${container_name}' container."
        return 1
    fi
}

# Display help information
show_help() {
    echo "Usage: $0 [--help]"
    echo
    echo "This script starts Docker containers for the Detector Controller Software in a development environment."
    echo
    echo "The old containers will be deleted and replaced."
    echo
    echo "Options:"
    echo "  --help     Display this help message and exit."
}

# Check for --help option
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Start gmp container
start_container "gmp" "registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server:current"
gmp_status=$?

# Start gnirsdc devel container
docker rm -f gnirsdc
docker pull registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-dev:latest
docker run -it --network=host --privileged --name gnirsdc -v /readout_data:/readout_data -v /staging/perm:/staging/perm -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-dev:latest bash
gnirsdc_status=$?
