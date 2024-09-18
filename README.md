# Detector Controller Software

The DC software is a collection of Python scripts and Bash scripts for managing the Detector Controller Software and GMP containers. It is designed to work with an SDSU ARC (San Diego State University Astronomical Research Cameras) controller.

The software is run in Docker containers, providing isolation and portability. It can be interfaced with through either an HTML-based [System Manager](#system-manager), a PyDM screen, or Bash control scripts.

The GMP (Gemini Master Process) is used for GIAPI (Gemini Instrument Application Programming Interface) communication. It works in conjunction with the GDS (Gemini Data System) to process FITS files.

## Detector Controller Usage

1. SSH to one of the required IRDC servers (gn-irdc-lp1, gn-irdc-lp2, gn-irdc-lp3)

2. Start the [System Manager](#system-manager):

   ```
   dc-system-manager.sh
   ```

   Note: This script must be run as the telops user. Ensure that the telops user has an SSH key set up before starting the System Manager.

3. Open a web browser and navigate to `http://<server ip address>:8080`

4. Use the System Manager web interface to monitor and configure the Detector Controller Software.

Alternatively, you can use the following commands to manage the Detector Controller Software and GMP containers:

- To start:
  ```
  dc-start.sh [additional arguments]
  ```
  Example with additional arguments:
  ```
  dc-start.sh --top tgnirs
  ```

- To stop:
  ```
  dc-stop.sh
  ```

- To check status:
  ```
  dc-status.sh
  ```

## DM Screen Usage

From a workstation with access to the IRDC server (currently hbfcon03 and mkocon05)

```
irdc_dm.sh
```

From a remote system

```
ssh -X <irdc server> "irdc_dm_server.sh"
```
or 

```
ssh -X <irdc server> 
irdc_dm_server.sh
```

## Data Retrieval

Raw data is stored in the `/readout_data/fits` directory on the IRDC server.

```
/readout_data/fits
```

Once processed the data is moved to the `/staging/perm` directory on the IRDC server.

```
/staging/perm
```

Use the web interface to navigate to the data and download it to a local system for viewing.

Alternatively you can scp the data to a local system for viewing.

Example:

``` 
scp <user>@<server>:/readout_data/fits/* .
```



## Scripts

1. `dc-start.sh [additional arguments]`
   - Starts the Detector Controller Software
   - Removes the existing `gmp` container if it exists
   - Runs a new `gmp` container using the specified Docker image
   - Removes the existing `gnirsdc` container if it exists
   - Runs a new `gnirsdc` container using the specified Docker image, with privileged access, host network, and a volume mount
   - Accepts optional additional arguments that are passed to the `gnirsdc` container

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

``` 
Kernel on gn-irdc-lp1 and gn-irdc-lp3
4.18.0-348.20.1.el8_5.x86_64
```

The driver code and installation instruction are in this repository:

``` 
https://gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirs-pci-driver
```

## Docker Login

**Note:** If `dc-latest.sh` doesn't work, you may need to log in to Docker.

Docker login is required to pull the images that the DC and DM screens are deployed in. The telops user has access to start/stop the containers but does not have access to gitlab registry. A user with access to the registry is needed to pull the images.

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

```
echo "your-personal-access-token" | docker login registry.gitlab.com -u your-gitlab-username --password-stdin
```

- Replace \`your-gitlab-username\` with your actual GitLab username.
- Replace \`your-personal-access-token\` with the token you copied earlier.

**Example:**

```
echo "glpat-xxxxxxxxxxxxxx" | docker login registry.gitlab.com -u johndoe --password-stdin
```

**Note:** Ensure that your user on the IRDC server is a member of the \`docker\` group.



# How to Build gnirsdc-lib

The gnirsdc-lib is a C++ library with Python bindings (using Pybind11) designed to control the SDSU ARC (San Diego State University Astronomical Research Cameras) controller. It handles firmware loading and execution of firmware calls.

To build the library:

1. **Clone the Repository:**

   ```
   git clone git@gitlab.com:nsf-noirlab/gemini/rtsw/iocs/gnirsdc-lib.git
   ```

2. **Setup Development Environment:**
   - Open the cloned directory in Visual Studio Code.
   - Use the Command Palette (Ctrl+Shift+P) to start the development container.

3. **Build Process:**
   The project uses a GitLab CI/CD pipeline for automated building and deployment:
   - It creates a Docker image for the build environment.
   - Builds the library within this container.
   - If changes are detected in `libgnirsioc.so`, it commits and pushes these changes.
   - Triggers a deployment in the `gnirsdc-data-manager` project to use the updated library.

4. **Manual Build (if needed):**
   Inside the development container:

   ```
   make clean all
   ```
   
   ```
   pip3.9 install .
   ```

This process ensures that the library is built consistently and that dependent projects are updated accordingly.





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

The System Manager is a web-based interface for monitoring and configuring the Detector Controller Software. It provides an easy-to-use interface for viewing system status, editing configuration files, and performing various actions.

## Usage

The System Manager must be started with the telops user. The telops user must have an SSH key set up before starting the System Manager. If you haven't set up an SSH key yet, you can do so by running:

```
ssh-keygen
```

To start the System Manager, use the provided script:

```
dc-system-manager.sh
```

This script will:
1. Check if it's being run by the telops user
2. Remove any existing System Manager container
3. Start a new System Manager container with the necessary configurations

Options:
- `--help`: Display help information
- `--debug`: Start the System Manager Server in debug mode

Example usage:
```
dc-system-manager.sh --debug
```

After starting the System Manager, open a web browser and navigate to `http://localhost:8080` (or the appropriate IP address if accessing remotely).

## Features

The System Manager offers several features accessible through different tabs:

1. **Monitoring**: View the current status of the system, including:
   - GNIRS DC Health
   - GNIRS DC State
   - Epics Top
   - GDS Connection
   - TCS Connection
   - Temperature
   - Controller Initialization
   - Temperature Interlock
   - Detector Bias Voltage

2. **Config Editor**: Edit the configuration file directly through the web interface.

3. **Logs**: View and download log files.

4. **FITS Files**: Browse and download FITS files from both staging and readout directories.

5. **README**: View the README file with a table of contents for easy navigation.

### Monitoring Tab

The monitoring tab provides real-time updates on various system parameters and allows users to perform actions such as:
- Initializing the controller
- Clearing errors
- Applying TDL
- Starting and stopping the controller
- Setting integration parameters
- Starting integration

### Config Editor Tab

The Config Editor tab allows users to modify the configuration file (`config.ini`) directly through the web interface. Changes are saved and applied immediately.

### Logs Tab

The Logs tab provides access to log files stored in the configured log directory. Users can view and download these logs for troubleshooting and monitoring purposes.

### FITS Files Tab

The FITS Files tab allows users to browse, view headers, and download FITS files from both the staging and readout directories.

### README Tab

The README tab displays the contents of the README file with a table of contents for easy navigation.

## Technical Details

The System Manager is built using:
- Flask: A lightweight WSGI web application framework
- Caproto: A pure-Python channel access protocol library
- Server-Sent Events (SSE): For real-time updates without polling
- Paramiko: For executing SSH commands on the host machine

Key features of the code include:
- Custom `AlignedCasePreservingConfigParser` for maintaining the format of the config file
- Real-time PV updates using Caproto subscriptions
- Integration with EPICS for controlling and monitoring the detector
- SSH command execution for starting and stopping the controller

## Note

Ensure that you have the necessary permissions to read and write the configuration file (`conf/gnirsdc/config.ini`) and access the log and FITS file directories when using the System Manager.
