# Detector Controller Software

This repository contains two bash scripts for managing the Detector Controller Software and GMP containers.

## Scripts

1. `start-dc.sh`
  - Starts the Detector Controller Software
  - Removes the existing `gmp` container if it exists
  - Runs a new `gmp` container using the specified Docker image
  - Removes the existing `gnirsdc` container if it exists
  - Runs a new `gnirsdc` container using the specified Docker image, with privileged access, host network, and a volume mount

2. `stop-dc.sh`
  - Stops the Detector Controller Software
  - Checks if the `gnirsdc` container is running and stops it if found
  - Removes the `gnirsdc` container if it exists
  - Checks if the `gmp` container is running and stops it if found
  - Removes the `gmp` container if it exists

## Usage

To start the Detector Controller Software and GMP containers, run:

```bash
./start-dc.sh
```

To stop the Detector Controller Software and clean up the containers, run:

```
bash
./stop-dc.sh
```