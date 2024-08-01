#!/bin/bash

echo "Starting Detector Controller Software"

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
    echo "This script starts Docker containers for the Detector Controller Software using the current image tag."
    echo
    echo "The old containers will be deleted and replaced."
    echo
    echo "Options:"
    echo "  --help     Display this help message and exit."
}



# Start gmp container
start_container "gmp" "registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server:current"
gmp_status=$?

# Start gnirsdc container
start_container "gnirsdc" "registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run:current"
gnirsdc_status=$?

# If any of the containers failed to start, run dc-production.sh and try again
if [ $gmp_status -ne 0 ] || [ $gnirsdc_status -ne 0 ]; then
    echo "One or more containers failed to start. Running dc-production.sh..."
    dc-production.sh

    # Try starting the containers again
    start_container "gmp" "registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server:current"
    start_container "gnirsdc" "registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run:current"
fi
