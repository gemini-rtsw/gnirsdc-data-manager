#!/bin/bash

echo "Starting GMP Container"

start_gmp_container() {
    container_name="gmp"
    image_name="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server:current"

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
    output=$(docker run -d --network=host --privileged --name ${container_name} \
        -v /readout_data:/readout_data \
        -v /staging/perm:/staging/perm \
        -v /etc/localtime:/etc/localtime:ro \
        -v /etc/timezone:/etc/timezone:ro \
        ${image_name})

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
    echo "This script starts the GMP Docker container for the Detector Controller Software using the current image tag."
    echo
    echo "The old GMP container will be deleted and replaced."
    echo
    echo "Options:"
    echo "  --help     Display this help message and exit."
}

# Check for help flag
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Start gmp container
start_gmp_container
gmp_status=$?

# If the container failed to start, run dc-production.sh and try again
if [ $gmp_status -ne 0 ]; then
    echo "GMP container failed to start. Running dc-production.sh..."
    dc-production.sh

    # Try starting the container again
    start_gmp_container
fi
