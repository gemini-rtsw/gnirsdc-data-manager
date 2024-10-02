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

    # Get telops user information
    TELOPS_UID=$(id -u)
    TELOPS_GID=$(id -g)

    # Run the container
    echo "Running the '${container_name}' container..."
    output=$(docker run -d \
        --network=host \
        --privileged \
        --name ${container_name} \
        -v /readout_data:/readout_data \
        -v /staging/perm:/staging/perm \
        -v /etc/localtime:/etc/localtime:ro \
        -v /etc/timezone:/etc/timezone:ro \
        -v /home/telops/.ssh:/home/telops/.ssh:ro \
        -v /etc/passwd:/etc/passwd:ro \
        -v /etc/group:/etc/group:ro \
        -v /etc/shadow:/etc/shadow:ro \
        -u ${TELOPS_UID}:${TELOPS_GID} \
        ${image_name})

    # Ensure correct SSH key permissions
    docker exec ${container_name} chmod 600 /home/telops/.ssh/id_rsa

    # Add localhost to known_hosts
    docker exec ${container_name} ssh-keyscan -H localhost >> /home/telops/.ssh/known_hosts

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

# Get telops user information
TELOPS_UID=$(id -u)
TELOPS_GID=$(id -g)

docker run -it \
    --network=host \
    --privileged \
    --name gnirsdc \
    -v /readout_data:/readout_data \
    -v /staging/perm:/staging/perm \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/timezone:/etc/timezone:ro \
    -v /home/telops/.ssh:/home/telops/.ssh:ro \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /etc/shadow:/etc/shadow:ro \
    -u ${TELOPS_UID}:${TELOPS_GID} \
    registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-dev:latest bash

# Ensure correct SSH key permissions
docker exec gnirsdc chmod 600 /home/telops/.ssh/id_rsa

# Add localhost to known_hosts
docker exec gnirsdc ssh-keyscan -H localhost >> /home/telops/.ssh/known_hosts

gnirsdc_status=$?
