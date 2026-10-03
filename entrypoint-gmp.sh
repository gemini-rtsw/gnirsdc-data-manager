#!/bin/bash
# GMP container entrypoint (dc-start.sh runs the gmp container from the same
# image as the DC, with this entrypoint).
#
# The GMP server is unpacked at /usr/local/share/gmp-server with this repo's
# conf/gmp already copied over its conf/ when the image was built.

cd /usr/local/share/gmp-server
./bin/gmp-server-ctl.sh start
# Keep the script running
while true; do sleep 1; done
