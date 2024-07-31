#!/bin/bash

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

# Promote the current tag to production for both images
promote_to_production "$GNIRSDC_DM_IMAGE" "GNIRSDC DM Screen"
promote_to_production "$GMP_IMAGE""GMP Server"
promote_to_production "$GNIRSDC_IMAGE" "GNIRSDC Run"

echo "Promotion process completed."
