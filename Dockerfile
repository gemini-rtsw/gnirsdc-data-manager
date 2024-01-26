# Use Rocky Linux 8 as the base image
# NOTE:  this Dockerfile does not build on macos
FROM rockylinux/rockylinux:8

# Maintainer label
LABEL maintainer="hawi.stecher@noirlab.edu"

# -- Instructions 
# ---- DC 
# git clone gnirsdc-data-manager

# ---- GIAPI GLUE and GMP
# untar giapi and gmp tar files from IGRINS2 project into gnirsdc-data-manager dir 
# for gmp you can also run registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server
#      see: Dockerfile.gmp

# ---- DC runtime environment build
# build this Dockerfile (it doesn't build on MacOS as of 2023) 
# in the container pip3 install . in the following repos:
# gnirsdc-tools, pycadcar, gnirsdc-lib

# ---- DC runtime enironment pull
# or pull registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run-img
# docker run -itd --name gnirsdc --privileged --network=host -v `pwd`:/work registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-run-img bash -l
# in the container source giapi/defineGiapiglueEnv.sh
# cd src/gnirsDataManager
# python3.9 gnirsdm.py [--list-pvs] --data-dir /readout_data/


# Run package updates
RUN dnf -y update
RUN dnf -y install python3.9
RUN dnf -y install gcc-c++ make cmake libstdc++ libgcc python39-devel java-1.8.0
RUN STDCXX=11 MAKE_NPROCS=12 python3 -m pip install cppyy==2.4.0 --verbose --no-binary=cppyy-cling
RUN ln -s /usr/local/lib64/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so /usr/local/lib/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so


RUN python3.9 -m pip install caproto
RUN python3.9 -m pip install asyncinotify

RUN git clone pycadcar
RUN cd pycadcar
RUN python3.9 -m pip install .
RUN cd ..

RUN git clone gnirsdc-lib
RUN cd gnirsdc-lib
RUN python3.9 -m pip install .
RUN cd ..

RUN git clone gnirsdc-tools
RUN cd gnirsdc-tools
RUN python3.9 -m pip install .
RUN cd ..

RUN mkdir -p /readout_data/new

# Start bash
CMD ["/bin/bash"]



