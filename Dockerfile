# GNIRS Detector Controller application image.
#
# One image, three containers, all started on the DC host:
#   system_manager_server  gnirsdc-system-manager.service (python3 system_manager_server.py)
#   gnirsdc                dc-start.sh, this image's ENTRYPOINT (the IOC + data manager)
#   gmp                    dc-start.sh, --entrypoint /gnirsdc/entrypoint-gmp.sh
#
# Built by gemini-rtsw-ci (build_app_image.sh) right after build_rpm.sh, in the
# same job, and tagged from the spec version. The RPM's unit and dc-start.sh pin
# <version>-git<hash>.
#
# BASE: this repo's dev image, which build_rpm.sh has just built locally under
# this name. It is the build environment plus everything the spec pins in
# BuildRequires -- gnirsdc-lib (libgnirsioc), pycadcar (pygeminirec),
# giapi-glue-cc and gmp-server from rpm-repo -- so those come in at exactly the
# pinned builds.
# The el9 in this tag must match el_version in .github/workflows/ci.yml.
FROM ghcr.io/gemini-rtsw/gnirsdc-data-manager:el9-latest-devel

LABEL maintainer="hawi.stecher@noirlab.edu"

# The dev image points dnf at the rpm-repo container, which only exists during
# build_rpm.sh. Everything below comes from the Rocky, EPEL and powertools repos.
RUN rm -f /etc/yum.repos.d/rpm-repo.repo

# Build tools for the pip installs below (EL9's python3 is 3.9); sudo for the
# GMP server (GDS chowns FITS files to gemdhs). Java 8, ps and libxcrypt-compat
# come in with the gmp-server and giapi-glue-cc RPMs.
RUN dnf -y install \
        python3 python3-devel python3-pip \
        gcc-c++ make git sudo && \
    dnf clean all && rm -rf /var/cache/dnf

# cppyy, with cppyy-cling built from source for C++11 as before: gnirsgiapi.py
# uses it to load the GIAPI C++ glue, whose headers use dynamic exception
# specifications (throw (GiapiException)) that C++17 removed. This is the slow
# step.
#
# Two fixes to build cppyy-cling 6.27 on EL9:
#  - Its CMakeLists does not configure with current CMake ("if given arguments
#    ... Unknown arguments specified"), and pip builds it in an isolated
#    environment that installs the latest cmake. A pip constraint applies inside
#    that environment too, so pin cmake there.
#  - Below C++17 cling uses its bundled string_view backport, which uses
#    std::numeric_limits without including <limits>; GCC 11's libstdc++ no
#    longer pulls it in. Patched into the source, since both the compiler and
#    cling's own precompiled-header step read that header.
RUN cd /tmp && \
    curl -fsSLO https://files.pythonhosted.org/packages/source/c/cppyy-cling/cppyy-cling-6.27.0.tar.gz && \
    echo "9c077c2b31e002cae7c9f48b4b5863611e7f392353cc7c66317d2ff6503a392d  cppyy-cling-6.27.0.tar.gz" | sha256sum --check --strict && \
    tar -xzf cppyy-cling-6.27.0.tar.gz && \
    sv=cppyy-cling-6.27.0/src/core/foundation/inc/ROOT/libcpp_string_view.h && \
    sed -i 's|^#include <stdexcept>$|#include <stdexcept>\n#include <limits>|' "$sv" && \
    grep -qx '#include <limits>' "$sv" && \
    echo "cmake<3.25" > pip-constraints.txt && \
    PIP_CONSTRAINT=/tmp/pip-constraints.txt STDCXX=11 MAKE_NPROCS=$(nproc) \
        python3.9 -m pip install --no-cache-dir ./cppyy-cling-6.27.0 && \
    python3.9 -m pip install --no-cache-dir wheel && \
    # cppyy-backend and CPyCppyy compile against cling's headers. Isolated, pip
    # would build them against a fresh, unpatched cppyy-cling wheel; without
    # isolation they use the patched one just installed.
    STDCXX=11 MAKE_NPROCS=$(nproc) \
        python3.9 -m pip install --no-cache-dir --no-build-isolation cppyy==2.4.0 && \
    rm -rf /tmp/cppyy-cling-6.27.0* /tmp/pip-constraints.txt && \
    ln -s /usr/local/lib64/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so \
          /usr/local/lib/python3.9/site-packages/cppyy_backend/lib/libcppyy_backend.so

RUN python3.9 -m pip install --no-cache-dir \
        caproto asyncinotify flask flask-socketio \
        astropy==5.1 docopt numpy==1.23.1 pyepics inotify-simple scipy \
        pyserial paramiko markdown2 matplotlib psutil requests

# GMP data owner (GDS SetOwnershipPolicy: owner=gemdhs). uid 1000 is what the old
# GMP image gave it, so FITS files in /staging/perm keep the same owner.
RUN useradd -m -u 1000 gemdhs

# GIAPI C++ glue (/opt/giapi-glue-cc) and the GMP server (/opt/gmp-server),
# built by another team, come from the giapi-glue-cc and gmp-server RPMs the
# spec pins (packaged in the gnirsdc-giapi-gmp repo). /gnirsdc/giapi-glue-cc
# is where entrypoint.sh and older scripts expect GIAPI; GMP gets this repo's
# configuration over its conf/.
RUN mkdir -p /gnirsdc && ln -s /opt/giapi-glue-cc /gnirsdc/giapi-glue-cc
COPY conf/gmp/ /opt/gmp-server/conf/

ENV JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk \
    GIAPI_ROOT=/opt/giapi-glue-cc \
    BOOST_ROOT=/opt/giapi-glue-cc/external/boost \
    LD_LIBRARY_PATH=/usr/lib64:/usr/lib:/opt/giapi-glue-cc/external/apr/lib:/opt/giapi-glue-cc/external/apr-util/lib:/opt/giapi-glue-cc/external/activemq-cpp/lib:/opt/giapi-glue-cc/external/log4cxx/lib:/opt/giapi-glue-cc/external/cppunit/lib:/opt/giapi-glue-cc/external/curlpp/lib:/opt/giapi-glue-cc/external/curlpp/lib64:/opt/giapi-glue-cc/external/libcurl/lib:/opt/giapi-glue-cc/external/libcurl/lib64:/opt/giapi-glue-cc/install/lib

# This repo, at /gnirsdc as before (see .dockerignore for what is left out).
COPY . /gnirsdc

# The commit this image was built from, for the DCVER3 FITS keyword: there is no
# .git in the image. Written by build_rpm.sh, which always runs first.
COPY rpms/.githash /gnirsdc/.githash

RUN mkdir -p /gnirsdc/static/js /readout_data/new && \
    curl -fsSL https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js \
         -o /gnirsdc/static/js/socket.io.js

WORKDIR /gnirsdc
ENTRYPOINT ["/gnirsdc/entrypoint.sh"]
