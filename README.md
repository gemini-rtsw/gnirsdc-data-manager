# Detector Controller Software

This repository contains bash scripts for managing the Detector Controller Software and GMP containers.

## Scripts

1. `dc-start.sh`
   - Starts the Detector Controller Software
   - Removes the existing `gmp` container if it exists
   - Runs a new `gmp` container using the specified Docker image
   - Removes the existing `gnirsdc` container if it exists
   - Runs a new `gnirsdc` container using the specified Docker image, with privileged access, host network, and a volume mount

2. `dc-stop.sh`
   - Stops the Detector Controller Software
   - Checks if the `gnirsdc` container is running and stops it if found
   - Removes the `gnirsdc` container if it exists
   - Checks if the `gmp` container is running and stops it if found
   - Removes the `gmp` container if it exists

3. `dc-status.sh`
   - Checks the status of the Detector Controller Software
   - Verifies if the `gnirsdc` container is running and displays its status
   - Verifies if the `gmp` container is running and displays its status

## Usage

ssh to one of the required IRDC servers (gn-irdc-lp1, gn-irdc-lp2, gn-irdc-lp3)

Use the following commands to manage the Detector Controller Software and GMP containers, run:

```bash
./dc-start.sh
```

```bash
./dc-stop.sh
```

```bash
./dc-status.sh
```

## Note

Your user on the IRDC server must be a memeber of the docker group


