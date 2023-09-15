# Use Rocky Linux 8 as the base image
# NOTE:  this Dockerfile does not build on macos
FROM rockylinux/rockylinux:8

# Maintainer label
LABEL maintainer="your-email@example.com"

# Run package updates
RUN dnf -y update
RUN dnf -y install python3.9
RUN dnf -y install gcc-c++ make cmake libstdc++ libgcc python39-devel
RUN STDCXX=11 MAKE_NPROCS=12 python3 -m pip install cppyy==2.4.0 --verbose --no-binary=cppyy-cling
RUN ln -s /usr/local/lib64/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so /usr/local/lib/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so


# Start bash
CMD ["/bin/bash"]
