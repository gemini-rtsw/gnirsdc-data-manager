#!/bin/bash

# Define the Docker image names
GNIRSDC_GM_IMAGE="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-dm-screens/gnirsdc-dm-run"
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

# Update tags for both images to testing
update_tag "${GNIRSDC_GM_IMAGE}" "latest"
update_tag "${GMP_IMAGE}" "latest"
update_tag "${GNIRSDC_IMAGE}" "latest"

echo "Tags have been updated to 'latest' as 'current'."
