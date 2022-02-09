%define _prefix /gem_base/epics/ioc
%define gemopt opt
%define name gnirsdcDataManager
%define repository gemdev
%define debug_package %{nil}
%define arch %(uname -m)
%define checkout %(git log --pretty=format:'%h' -n 1) 

#These global defines are added to prevent stripping
# symbols on vxWorks cross-compiled code
# Getting 'strip' to work is probably only needed for
# building a related debug sub-package
#
# But this prevents all the strip warnings
# mrippa 20120202
%global _enable_debug_package 0
%global debug_package %{nil}
%global __os_install_post /usr/lib/rpm/brp-compress %{nil}

Summary: %{name} gnirs Python Data Manager
Name: %{name}
Version: 0.1.0
Release: 3%{?dist}
License: Proprietary
Group: Applications/Engineering
Source0: %{name}-%{version}.tar.gz
ExclusiveArch: %{arch}
Prefix: %{_prefix}
Requires: python3.8 gnirsdc-tools


%description
GNIRS Python Data Manager converts raw frames and header data from the GNIRS ARC controller to a fits file. 

%prep
%setup -q


%build

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/%{name}
cp -r *.toml $RPM_BUILD_ROOT/%{_prefix}/%{name}
cp -r *.py $RPM_BUILD_ROOT/%{_prefix}/%{name}
cp -r *.cfg $RPM_BUILD_ROOT/%{_prefix}/%{name}
cp -r *.sh $RPM_BUILD_ROOT/%{_prefix}/%{name}
cp -r *.service $RPM_BUILD_ROOT/%{_prefix}/%{name}
cp -r src $RPM_BUILD_ROOT/%{_prefix}/%{name}

%post
mkdir /home/readout_data
mkdir /home/readout_data/log
mkdir /home/readout_data/error
mkdir /home/readout_data/unscrambled
mkdir /home/readout_data/processing
mkdir /home/readout_data/fits
mkdir /home/readout_data/new
cd %{_prefix}/%{name}/
source /usr/local/etc/gnirsdc-env/bin/activate
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir .
cp gnirsdm.service /etc/systemd/system/


%postun

%clean
## Usually you won't do much more here than
rm -rf %{buildroot}

%files
%defattr(-,root,root)
   /%{_prefix}/%{name}


%changelog
* Tue Feb 08 2022 Hawi Stecher <hstecher@gemini.edu> 0.1.0-3
- new package built with tito


