#!/bin/bash
# Run by gemini-rtsw-ci/build_rpm.sh just before `dnf builddep`.
set -euo pipefail

# Local testing only: RPMs dropped in local-rpms/ (gitignored) are installed
# first, so this repo can be built against a gnirsdc-lib or pycadcar build that
# is not in rpm-repo yet. Absent in CI.
if ls local-rpms/*.rpm >/dev/null 2>&1; then
    echo "Installing local RPMs: $(ls local-rpms/*.rpm)"
    dnf -y install local-rpms/*.rpm
fi
