# gnirsdc-data-manager: deploys the GNIRS Detector Controller on its host.
#
# The software itself runs from the container image built from this repo's
# Dockerfile. This RPM installs what the host needs to run it:
#   - gnirsdc-system-manager.service: runs the System Manager container at boot
#   - /usr/local/bin/dc-start.sh, dc-stop.sh, dc-status.sh: what the System
#     Manager runs over SSH to start and stop the gmp and gnirsdc containers
#   - /etc/sysconfig/gnirsdc: host settings
#
# The unit and dc-start.sh are pinned to the image tag matching this package,
# so `rpm -q gnirsdc-data-manager` tells you what runs and `dnf downgrade` is a
# real rollback. This replaces the old current/production tag promotion.

%global specver 1.0.0
# $GIT_HASH first: build_rpm.sh computes it on the host and passes it in.
%define git_hash %(if [ -n "$GIT_HASH" ]; then echo "$GIT_HASH"; else git rev-parse --short HEAD 2>/dev/null || echo nogit; fi)

%global appimage ghcr.io/gemini-rtsw/gnirsdc-data-manager
# Pin the NVR-unique tag: build_app_image.sh retags a bare :<version> on every
# build of that version, which would make a downgrade a no-op for the image.
%global imagetag %{appimage}:%{version}-git%{git_hash}

Name:           gnirsdc-data-manager
Version:        %{specver}
Release:        1.git%{git_hash}%{?dist}
Summary:        GNIRS Detector Controller host deployment (System Manager unit, dc-* scripts)
License:        Proprietary
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros
# Not needed to build this RPM. They are here so the dev image -- this build's
# environment -- contains them at exactly these builds, and the application
# image (Dockerfile, FROM the dev image) inherits them. Pins come from the
# "BUILD DEPENDENCY VERSIONS" block of a green build of each repo.
BuildRequires:  gnirsdc-lib = 0.2.0-1.git0d7dbc3%{?dist}
BuildRequires:  pycadcar = 0.1.0-1.git1853575%{?dist}
BuildRequires:  python3

Requires:       systemd
# Deliberately NOT Requires: docker. Docker on these hosts is not always from
# an RPM that declares it; the unit's Requires=docker.service catches a
# missing daemon at start time instead.

%description
Host deployment for the GNIRS Detector Controller. Installs the
gnirsdc-system-manager systemd unit, which runs the System Manager web UI, and
the dc-start.sh / dc-stop.sh / dc-status.sh scripts it uses to start and stop
the gmp and gnirsdc containers. All three containers run the image
%{imagetag}.

After installing, check /etc/sysconfig/gnirsdc, then:

    systemctl enable --now gnirsdc-system-manager

%prep
%setup -q

%build
sed -e 's|@IMAGE@|%{imagetag}|' deploy/gnirsdc-system-manager.service.in > gnirsdc-system-manager.service
sed -e 's|@IMAGE@|%{imagetag}|' deploy/dc-start.sh.in > dc-start.sh
if grep -q '@IMAGE@' gnirsdc-system-manager.service dc-start.sh; then
    echo "ERROR: placeholder not substituted" >&2; exit 1
fi

%install
install -Dpm 0644 gnirsdc-system-manager.service %{buildroot}%{_unitdir}/gnirsdc-system-manager.service
install -Dpm 0755 deploy/run-system-manager      %{buildroot}%{_libexecdir}/%{name}/run-system-manager
install -Dpm 0644 deploy/gnirsdc.sysconfig       %{buildroot}%{_sysconfdir}/sysconfig/gnirsdc
# /usr/local/bin because that is where the System Manager runs them over SSH.
install -Dpm 0755 dc-start.sh         %{buildroot}/usr/local/bin/dc-start.sh
install -Dpm 0755 deploy/dc-stop.sh   %{buildroot}/usr/local/bin/dc-stop.sh
install -Dpm 0755 deploy/dc-status.sh %{buildroot}/usr/local/bin/dc-status.sh

%check
# The unit (System Manager) and dc-start.sh (gmp, gnirsdc) must pin the same
# image, and it must be this build's.
grep -qx 'Environment=PINNED_IMAGE=%{imagetag}' %{buildroot}%{_unitdir}/gnirsdc-system-manager.service \
    || { echo "ERROR: unit image pin missing or wrong" >&2; exit 1; }
grep -qx 'PINNED_IMAGE="%{imagetag}"' %{buildroot}/usr/local/bin/dc-start.sh \
    || { echo "ERROR: dc-start.sh image pin missing or wrong" >&2; exit 1; }
bash -n %{buildroot}/usr/local/bin/dc-start.sh
bash -n %{buildroot}%{_libexecdir}/%{name}/run-system-manager

%post
%systemd_post gnirsdc-system-manager.service

%preun
%systemd_preun gnirsdc-system-manager.service

%postun
# Deliberately not _with_restart: restarting the System Manager mid-upgrade
# would interrupt an operator, and the DC only moves to the new image on its
# next Restart DC anyway. Restart the unit when ready.
%systemd_postun gnirsdc-system-manager.service

%files
%{_unitdir}/gnirsdc-system-manager.service
%{_libexecdir}/%{name}
%config(noreplace) %{_sysconfdir}/sysconfig/gnirsdc
/usr/local/bin/dc-start.sh
/usr/local/bin/dc-stop.sh
/usr/local/bin/dc-status.sh

%changelog
* Fri Oct 02 2026 Hawi Stecher <hawi.stecher@noirlab.edu> - 1.0.0-1
- Build and deploy with gemini-rtsw-ci on GitHub. Image pinned by the RPM;
  replaces the current/production tag promotion scripts.
