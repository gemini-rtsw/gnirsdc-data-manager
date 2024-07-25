#!/bin/bash

cd /gmp-install
tar -xvf gmp-server-0.2.6-SNAPSHOT.tar.gz 
ln -s /gmp-install/gmp-server-0.2.6-SNAPSHOT /usr/local/share/gmp-server
cp -rf /gmp-install/gmp/* /usr/local/share/gmp-server/conf/

cd /usr/local/share/gmp-server
./bin/gmp-server-ctl.sh start
# Keep the script running
while true; do sleep 1; done

