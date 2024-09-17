# Detector Controller Software

The DC softtware is a collection of python scripts and bash scripts for managing the Detector Controller Software and GMP containers.

## Detector Controller Usage

ssh to one of the required IRDC servers (gn-irdc-lp1, gn-irdc-lp2, gn-irdc-lp3)

Start the System Manager

```bash
dc-start-system-manager.sh
```   

Open a web browser and navigate to `http://<server ip address>:80` 



Alternatively use the following commands to manage the Detector Controller Software and GMP containers, run:

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

Raw data is stored in the `/readout_data/fits` directory on the IRDC server.

```bash
/readout_data/fits
```

Once processed the data is moved to the `/staging/perm` directory on the IRDC server.

```bash
/staging/perm
```

Use the web interface to navigate to the data and download it to a local system for viewing.

Alternatively you can scp the data to a local system for viewing.

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

The driver code and installation instruction are in this repository:

```bash 
https://gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirs-pci-driver
```

## Docker Login

**Note:** If `dc-latest.sh` doesn't work, you may need to log in to Docker.

Docker login is required to pull the images that the DC and DM screens are deployed in.

### GitLab Docker Login with Personal Access Token Using `--password-stdin` Option

**Login to GitLab Website:**

Navigate to your GitLab instance (e.g., https://gitlab.com) and log in with your credentials.

**Create a Personal Access Token:**

1. Click on your profile avatar and select **"Edit profile"**.
2. Go to **"Access Tokens"**.
3. Enter a name for the token (e.g., `Docker Registry Access`).
4. Set an expiration date (optional but recommended).
5. Select the scopes:
   - `read_registry`
   - `read_repository`
6. Click on **"Create personal access token"**.
7. **Important:** Copy the generated token. You won't be able to see it again.

**Docker Login Using `--password-stdin`:**

For enhanced security, use the `--password-stdin` option to avoid exposing your access token in the shell history.

\`\`\`bash
echo "your-personal-access-token" | docker login registry.gitlab.com -u your-gitlab-username --password-stdin
\`\`\`

- Replace \`your-gitlab-username\` with your actual GitLab username.
- Replace \`your-personal-access-token\` with the token you copied earlier.

**Example:**

\`\`\`bash
echo "glpat-xxxxxxxxxxxxxx" | docker login registry.gitlab.com -u johndoe --password-stdin
\`\`\`

**Note:** Ensure that your user on the IRDC server is a member of the \`docker\` group.



# How to build gnirsdc-lib
## VSCode
## dev con
## pip3.9 install . 
### rm /usr/local/lib64/python3.9/site-packages/libgnirsioc.so 
### etc
## pipeline generated commit

# libgnirsioc python cmd line use

# how do run debug modes
## collect_dataset.py


# run dm screen
## linux
## mac
### export DISPLAY=host.docker.internal:0
### ./irdc_dm_server.sh

# debug mode in vscode

# gnirs-lib manual build
## /gnirsdc-lib
## make
## pip3.9 install .

# git setup 
## [root@docker-desktop gnirsdc-lib]# git config --global user.name "Hawi Stecher"
## [root@docker-desktop gnirsdc-lib]# git config --global user.email "hawi.stecher@noirlab.edu"

# dev container
## docker pull
## rebuild


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


for debug in vscode you must "tar -xvf giapi-gluecc_rocky8.tar.gz"



# System Manager

The System Manager is a web-based interface for monitoring and configuring the Detector Controller Software. It provides an easy-to-use interface for viewing system status and editing configuration files.

## Usage

To start the System Manager:

```
bash
python3 src/system_manager_server.py

```
Then, open a web browser and navigate to `http://localhost:80` (or the appropriate IP address if accessing remotely).

## Features

1. **Monitoring**: View the current status of the system (accessible via the "Monitoring" tab).
2. **Config Editor**: Edit the configuration file directly through the web interface (accessible via the "Config Editor" tab).

## Code Structure

The System Manager consists of the following main components:

1. `system_manager_server.py`: The main Flask application that handles routing and server-side logic.
2. `templates/base.html`: The base template for all pages, including the navigation tabs.
3. `templates/monitoring.html`: The template for the monitoring page.
4. `templates/config_editor.html`: The template for the configuration editor page.

### Key Features of the Code

- Uses Flask for the web framework
- Implements a custom `AlignedCasePreservingConfigParser` to maintain the format of the config file
- Provides a user-friendly interface for editing the configuration file
- Implements tabbed navigation for easy switching between monitoring and configuration

## Note

Ensure that you have the necessary permissions to read and write the configuration file (`conf/gnirsdc/config.ini`) when using the Config Editor feature.
