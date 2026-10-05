#!/bin/bash
# GMP container entrypoint (dc-start.sh runs the gmp container from the same
# image as the DC, with this entrypoint).
#
# The GMP server is installed at /opt/gmp-server (gmp-server RPM), with this
# repo's conf/gmp copied over its conf/ when the image was built.

cd /opt/gmp-server
./bin/gmp-server-ctl.sh start
# Keep the script running
while true; do sleep 1; done
