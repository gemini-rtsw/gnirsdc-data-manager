#!/bin/bash

docker rm -f gmp > /dev/null 2>&1

docker run -d --network=host --name gmp registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server
