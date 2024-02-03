#!/bin/bash

echo "Starting Detector Controller Software"

docker run -itd --name gnirsdc --privileged --network=host -v /readout_data:/readout_data registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run
