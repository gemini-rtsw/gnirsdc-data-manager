#!/bin/bash

echo "Starting Detector Controller Software"

docker run -itd --name gnirsdc --privileged --network=host registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run
