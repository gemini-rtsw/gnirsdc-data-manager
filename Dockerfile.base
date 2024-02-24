# Use Rocky Linux 8 as the base image
# NOTE:  this Dockerfile does not build on macos
FROM rockylinux/rockylinux:8

# Maintainer label
LABEL maintainer="hawi.stecher@noirlab.edu"

# -- To build the base evironment image
# 
#   git clone git@gitlab.com:nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager.git
#   git switch irdcioc
#   docker build -t registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-base
#   docker push registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-base
#
# -- To build the runtime environment follow Dockerfile.linux_run 
#


# Run package updates
RUN dnf -y update
RUN dnf -y install python3.9
RUN dnf -y install gcc-c++ make cmake libstdc++ libgcc python39-devel java-1.8.0
RUN STDCXX=11 MAKE_NPROCS=12 python3 -m pip install cppyy==2.4.0 --verbose --no-binary=cppyy-cling
RUN ln -s /usr/local/lib64/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so /usr/local/lib/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so


RUN python3.9 -m pip install caproto
RUN python3.9 -m pip install asyncinotify


RUN mkdir -p /readout_data/new

# Start bash
CMD ["/bin/bash"]



