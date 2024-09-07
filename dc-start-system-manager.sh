#!/bin/bash

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

    # Run the container
    echo "Running the '${container_name}' container..."
    output=$(docker run -d --network=host --privileged --name ${container_name} -v /readout_data:/readout_data -v /staging/perm:/staging/perm -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro ${image_name} ${command})

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
