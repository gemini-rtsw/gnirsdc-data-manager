# Detector Controller Software

This repository contains bash scripts for managing the Detector Controller Software and GMP containers.

## Detector Controller Usage

ssh to one of the required IRDC servers (gn-irdc-lp1, gn-irdc-lp2, gn-irdc-lp3)

Use the following commands to manage the Detector Controller Software and GMP containers, run:

```bash
dc-start.sh
```

```bash
dc-stop.sh
```

```bash
dc-status.sh
```

## DM Screen Usage

From a workstation with access to the IRDC server (currently hbfcon03 and mkocon05)

```bash
irdc_dm.sh
```

From a remote system

```bash
ssh -X <irdc server> "irdc_dm_server.sh"
```
or 

```bash
ssh -X <irdc server> 
irdc_dm_server.sh
```

## Data Retrieval

At the moment data will be written to the server at here:

```bash
/readout_data/fits
```

scp the data to a local system for viewing

Example:

```bash 
scp <user>@<server>:/readout_data/fits/* .
```



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

## Note

Your user on the IRDC server must be a memeber of the docker group

## Driver 

The DC uses the SDSU PCIe driver. The driver is officially supported on linux kernel 2 and 3. We run it on kernel 4. We have not had kernel issues on kernel version 4.18.0-348.20.1.el8_5.x86_64 and older.

```bash 
Kernel on gn-irdc-lp1 and gn-irdc-lp3
4.18.0-348.20.1.el8_5.x86_64
```

## Docker Login

Docker login is required to pull the images that the DC and DM screens are deployed in.

GitLab Docker login with Personal Access Token:

1. Login to GitLab website.
2. Go to **Settings**.
3. Navigate to **Access Tokens**.
4. Create a new token with `read_registry` and `read_repository` scopes.
5. Copy the personal access token.
6. Login to Docker with the following command, replacing `your-gitlab-username` and `your-personal-access-token` with your details:
   ```bash
   docker login registry.gitlab.com -u your-gitlab-username -p your-personal-access-token

For example:
```bash 
docker login registry.gitlab.com -u johndoe -p glpat-xxxxxxxxxxxxxx
```


Future notes:
IRDC Documentation Notes
Driver documentation
Kernel version
Repo
Build
Install
troubleshooting
DM Screen
Repo
Build
Install
Run
Use
