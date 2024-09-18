#!/bin/bash

# Check if the script is being run by the telops user
if [ "$(id -un)" != "telops" ]; then
    echo "Error: This script must be run as the telops user."
    exit 1
fi

echo "Starting System Manager Server"

start_container() {
    container_name=$1
    image_name=$2
    command=$3

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
        ${image_name} ${command})

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
    echo "Usage: $0 [--help] [--debug]"
    echo
    echo "This script starts the System Manager Server using the gnirsdc Docker image."
    echo
    echo "The old container will be deleted and replaced."
    echo
    echo "Options:"
    echo "  --help     Display this help message and exit."
    echo "  --debug    Start the System Manager Server in debug mode."
}

# Parse command line arguments
debug_flag=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --debug)
            debug_flag="--debug"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Start system manager server container
start_container "system_manager_server" "registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-dev:latest" "python3 /gnirsdc/src/system_manager_server.py $debug_flag"
system_manager_status=$?
