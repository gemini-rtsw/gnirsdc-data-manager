#!/bin/bash

# This script updates Docker images by pulling the latest 'production' tag
# and tagging it as 'current'. It ensure that the 'current' tag 
# points to the latest 'production' version of the images.
# A DC restart is required for the changes to take effect.

# Define the Docker image names
GNIRSDC_DM_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-dm-screens/gnirsdc-dm-run"
GMP_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server"
GNIRSDC_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run"

# Function to update the tag
update_tag() {
    local image=$1
    local new_tag=$2

    # Pull the image with the new tag
    echo "Pulling ${image}:${new_tag}..."
    docker pull "${image}:${new_tag}"

    # Tag the image as current
    echo "Tagging ${image}:${new_tag} as ${image}:current..."
    docker tag "${image}:${new_tag}" "${image}:current"
}

# Display help information
show_help() {
    echo "Usage: $0 [--help]"
    echo
    echo "This script updates Docker images by pulling the latest 'production' tag"
    echo "and tagging it as 'current'."
    echo
    echo "A DC restart is required for the changes to take effect."
    echo 
    echo "Options:"
    echo "  --help     Display this help message and exit."
}

# Check for --help option
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Update tags for all images to 'production'
update_tag "${GNIRSDC_DM_IMAGE}" "production"
update_tag "${GMP_IMAGE}" "production"
update_tag "${GNIRSDC_IMAGE}" "production"

echo "Tags have been updated to 'production' as 'current'."
