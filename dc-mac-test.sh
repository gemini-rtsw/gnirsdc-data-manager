#!/bin/bash
# macOS test setup: GMP + dev container (IOC + System Manager + TCS sim).
# - GMP owns the network namespace so 8008 (GIAPI) and host:HOST_PORT->8080 (web UI) are published there
# - gnirsdc-dev joins gmp's network so IOC can reach GMP at localhost:8008
# - IOC + System Manager + TCS sim run as detached `docker exec` processes inside gnirsdc-dev
#
# Usage:
#   ./dc-mac-test.sh           # start everything
#   ./dc-mac-test.sh stop      # remove containers
#   ./dc-mac-test.sh logs <name>   # tail logs (tcs-sim | ioc | sm)

set -e

REGISTRY="registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager"
GMP_IMAGE="${REGISTRY}/gmp-server:latest"
DEV_IMAGE="${REGISTRY}/gnirsdc-dev:latest"

HOST_PORT="${HOST_PORT:-8080}"      # Mac-side port for the System Manager web UI
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${HOME}/irdc_data"

stop_all() {
    echo "Stopping containers..."
    docker rm -f gnirsdc-dev gmp 2>/dev/null || true
}

case "${1:-start}" in
    stop)
        stop_all
        exit 0
        ;;
    logs)
        target="${2:-sm}"
        case "$target" in
            tcs-sim) docker exec gnirsdc-dev tail -f /tmp/tcs_sim.log ;;
            ioc)     docker exec gnirsdc-dev tail -f /tmp/ioc.log ;;
            sm)      docker exec gnirsdc-dev tail -f /tmp/sm.log ;;
            *) echo "unknown log target: $target (use tcs-sim | ioc | sm)"; exit 1 ;;
        esac
        exit 0
        ;;
    start) ;;
    *) echo "usage: $0 [start|stop|logs <tcs-sim|ioc|sm>]"; exit 1 ;;
esac

mkdir -p "${DATA_DIR}/readout_data" "${DATA_DIR}/staging/perm"

stop_all

echo "Starting gmp (publishing 8008 and ${HOST_PORT}->8080)..."
docker run -d --name gmp \
    -p 8008:8008 -p "${HOST_PORT}:8080" \
    -v "${DATA_DIR}/readout_data:/readout_data" \
    -v "${DATA_DIR}/staging/perm:/staging/perm" \
    "${GMP_IMAGE}" >/dev/null

echo "Starting gnirsdc-dev (sharing gmp's network)..."
docker run -itd --name gnirsdc-dev --privileged \
    --network=container:gmp \
    -v "${REPO_DIR}:/work" \
    -v "${DATA_DIR}/readout_data:/readout_data:rw" \
    -v "${DATA_DIR}/staging/perm:/staging/perm:rw" \
    "${DEV_IMAGE}" bash -l >/dev/null

echo "Launching TCS simulator..."
docker exec -d gnirsdc-dev bash -lc \
    "cd /work && python3 test/tcs_simulator.py >/tmp/tcs_sim.log 2>&1"

echo "Launching IOC..."
docker exec -d gnirsdc-dev bash -lc \
    "cd /work && python3 src/gnirsdm.py --debug --top tgnirs >/tmp/ioc.log 2>&1"

echo "Launching System Manager..."
docker exec -d gnirsdc-dev bash -lc \
    "cd /work && python3 src/system_manager_server.py --debug >/tmp/sm.log 2>&1"

echo
echo "Done. Web UI: http://localhost:${HOST_PORT}"
echo "Tail logs with: $0 logs [tcs-sim|ioc|sm]"
echo "Stop with:     $0 stop"
