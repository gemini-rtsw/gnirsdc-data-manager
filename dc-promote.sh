#!/bin/bash

# Script to promote Docker images from 'current' to 'production'
# The script tags the current production image with the current date and time for archival,
# and then promotes the current image to production.


# Define the Docker image names
GNIRSDC_DM_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-dm-screens/gnirsdc-dm-run"
GMP_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server"
GNIRSDC_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run"

# Function to promote the local current tag to production
promote_to_production() {
    local image=$1
    local name=$2

    echo "Processing $name..."

    # Tag the current production image with the current date and time
    local date_time_tag=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "Tagging local production image for $name as ${image}:${date_time_tag}..."
    docker tag "${image}:production" "${image}:${date_time_tag}"
    docker push "${image}:${date_time_tag}"
    echo "Archived as ${image}:${date_time_tag}."

    # Promote the local current image to production
    echo "Promoting local current image for $name to production..."
    docker tag "${image}:current" "${image}:production"
    docker push "${image}:production"
    echo "Successfully promoted to production."
}


# Display help information
show_help() {
    echo "Usage: $0 [--help]"
    echo
    echo "This script promotes Docker images from the 'current' tag to the 'production' tag."
    echo "It also archives the current 'production' image with a timestamp."
    echo
    echo "Options:"
    echo "  --help     Display this help message and exit."
    echo
    echo "The script promotes the following images:"
    echo "1. GNIRSDC DM Screen"
    echo "2. GMP Server"
    echo "3. GNIRSDC Run"
    echo
    echo "Each image will have its current 'production' tag archived with the current date and time,"
    echo "and the 'current' tag will be promoted to 'production'."
}

# Check for --help option
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi



# Promote the current tag to production for both images
promote_to_production "$GNIRSDC_DM_IMAGE" "GNIRSDC DM Screen"
promote_to_production "$GMP_IMAGE""GMP Server"
promote_to_production "$GNIRSDC_IMAGE" "GNIRSDC Run"

echo "Promotion process completed."
