#!/bin/bash
cd /usr/local/share/gmp-server-0.2.6-SNAPSHOT
./bin/gmp-server-ctl.sh start
# Keep the script running
while true; do sleep 1; done

