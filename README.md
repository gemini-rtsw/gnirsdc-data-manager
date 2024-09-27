# Detector Controller Software

The DC software is a collection of Python scripts and Bash scripts for managing the Detector Controller Software and GMP containers. It is designed to work with an SDSU ARC (San Diego State University Astronomical Research Cameras) controller.

The software is run in Docker containers, providing isolation and portability. It can be interfaced with through either an HTML-based [System Manager](#system-manager), a PyDM screen, or Bash control scripts.

The GMP (Gemini Master Process) is used for GIAPI (Gemini Instrument Application Programming Interface) communication. It works in conjunction with the GDS (Gemini Data System) to process FITS files.

## Quick Start Guide

1. **Power on the ARC Controller**
   - Ensure the ARC (Astronomical Research Cameras) controller is powered on and properly connected.

2. **Access the System Manager**
   - Open a web browser and navigate to `http://gn-irdc-lp3:8080`
   - This will open the System Manager interface, showing the Monitoring tab.

3. **Initialize the Controller**
   - On the Monitoring tab, locate the "Controller Initialization" section.
   - Click the "Initialize Controller" button.
   - Wait for the initialization process to complete. The status will update to "Initialized" when done.

4. **Set Temperature Override (if needed)**
   - Navigate to the Engineering tab by clicking "Engineering" in the top navigation bar.
   - Find the "Temperature Interlock Override" section.
   - Toggle the switch to enable or disable the temperature interlock override.
   - This allows operation even if the detector temperature is outside the normal range.

5. **Start the Controller**
   - Return to the Monitoring tab.
   - Locate the "Start/Stop Controller" section.
   - Click the "Start Controller" button to begin normal operations.


## Detector Controller Usage

1. SSH to one of the required IRDC servers (gn-irdc-lp1, gn-irdc-lp2, gn-irdc-lp3)

2. Start the [System Manager](#system-manager):

   ```
   dc-system-manager.sh
   ```

   If the DC is running in debug mode the System Manager must be started with the `--debug` option:

   ```
   dc-system-manager.sh --debug
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


## Detector Controller (DC) Operation Scripts

### dc-start.sh
Starts the Detector Controller Software and related Docker containers.
```
Usage: dc-start.sh [additional arguments]
```
- Additional arguments are passed to the `gnirsdc` container.
- Example: `dc-start.sh --top tgnirs` (for debug mode)

### dc-stop.sh
Stops the Detector Controller Software and removes related Docker containers.
```
Usage: dc-stop.sh
```
- No additional flags or arguments.

### dc-status.sh
Checks and displays the status of the Detector Controller Software containers.
```
Usage: dc-status.sh
```
- No additional flags or arguments.
- Displays running status of `gnirsdc` and `gmp` containers.

### dc-system-manager.sh
Launches the System Manager web interface for monitoring and controlling the DC software.
```
Usage: dc-system-manager.sh [--debug]
```
- `--debug`: Starts the System Manager in debug mode.
- `--help`: Displays help information.

### dc-devel.sh
Starts Docker containers for the Detector Controller Software in a development environment.
```
Usage: dc-devel.sh
```
- No additional flags or arguments.
- Attempts to start containers with development images.

### dc-production.sh
Updates Docker images by pulling the latest 'production' tag and tagging it as 'current'.
```
Usage: dc-production.sh
```
- No additional flags or arguments.
- Ensures 'current' tag points to the latest 'production' version.

### dc-latest.sh
Updates Docker images by pulling the latest 'latest' tag and tagging it as 'current'.
```
Usage: dc-latest.sh
```
- No additional flags or arguments.
- Ensures 'current' tag points to the most recent 'latest' version.

### dc-promote.sh
Promotes Docker images from 'current' to 'production' tag, archiving the old 'production' image.
```
Usage: dc-promote.sh [--help]
```
- `--help`: Displays help information about the script's functionality.

Note: These scripts should be run with appropriate permissions, typically as the 'telops' user or a user with Docker access.   

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


# Updating the Development Container

When changes occur in the development environment, such as a new gnirsdc-lib build or modifications to the Dockerfile, you need to update your local development container. Follow these steps to ensure you're working with the latest environment:

1. **Pull the latest Docker image:**

```
   docker pull registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-dev
```

   This command fetches the most recent version of the development container image.

2. **Rebuild the development container in VSCode:**
   - Open the Command Palette (Ctrl+Shift+P or Cmd+Shift+P on Mac)
   - Type and select "Remote-Containers: Rebuild Container"

This process ensures that your development environment is up-to-date with the latest changes, including any new dependencies or configurations.

**Note:** If you encounter any issues after updating, try removing the old container completely and rebuilding from scratch:
- Use the Command Palette in VSCode
- Select "Remote-Containers: Rebuild and Reopen in Container"

Remember to perform these steps whenever you're notified of significant changes to the development environment or if you experience unexpected behavior in your current setup.

# Changing TCS Process Variable (PV) in the TCS context

## 1. Modify the `fits_header_definitions.py` file
- **File path:** `src/fits_header_definitions.py`
- **Task:** Add the new TCS PV and ensure it is included in the TCS context.

- **Example change:**

```python
  # Define the new PV in the `define_hdu_list` function
  tcs_instr_pa = pdu.get('TCS_INSTR_PA', '')
  
  # Update the tcs_connected check to include the new PV
  tcs_connected = all([tcs_ra, tcs_dec, tcs_frame, tcs_equinox, tcs_time, tcs_port, tcs_camera, tcs_ao, tcs_instr_pa])
  
  # Add the new PV to the tcs_context dictionary
  tcs_context = {
      'instr_pa': tcs_instr_pa,
      # Other existing context entries...
  }
```

## 2. Modify the `tcs_monitor.py` file
- **File path:** `src/tcs_monitor.py`
- **Task:** Add the new PV to the `TCSMonitor` class to track the new TCS value.

- **Example change:**

```python   
  # Add the new PV to the `self.tcs_pvs` list
  self.tcs_pvs = [
      # Other existing PVs...
      f'{tcs_prefix}sad:instrPA',  # 'instrument position angle'
      f'{cc_prefix}cc:cameraPosition',  # 'camera' (optional)
  ]
  
  # Map the new PV to its corresponding TCSContext attribute
  mapping = {
      'instrPA': 'inst_pa',  # Changed from 'camera' to 'instrument_pa'
      # Other mappings...
  }
```

## 3. Update the Context Mapping
- Ensure the new PV is mapped correctly to the TCS context within the `mapping` dictionary in `tcs_monitor.py`. This will make sure the context is updated with the value from the new PV.

- **Example change in `mapping`:**

```python
  mapping = {
      # Other mappings...
      'instrPA': 'inst_pa',  # Ensure new PV is mapped correctly
  }
```

## Recap
1. **In `fits_header_definitions.py`:**
   - Add the new PV (`TCS_INSTR_PA`).
   - Update the `tcs_connected` check.
   - Include the new PV in the `tcs_context`.

2. **In `tcs_monitor.py`:**
   - Add the new PV to the `self.tcs_pvs` list.
   - Map the new PV to its corresponding attribute in the `mapping` dictionary.

# Detector Controller Software


## Debug Setup

For debugging purposes, you can set up the environment using the following steps:

1. **Start the GMP Server:**
   Run the following command to start the GMP (Gemini Master Process) server in a Docker container:

   ```bash
   docker run -d --network=host --name gmp \
     -v /Users/hawi.stecher/irdc_data/readout_data:/readout_data \
     -v /Users/hawi.stecher/irdc_data/staging/perm:/staging/perm \
     registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gmp-server
   ```

   This command mounts the necessary volumes for data storage and runs the GMP server in detached mode.

2. **Start the GNIRSDC Development Container:**
   Launch the GNIRSDC development container with the following command:

   ```bash
   docker run -itd --name gnirsdc-dev --privileged --network=host \
     -v `pwd`:/work \
     registry.gitlab.com/nsf-noirlab/gemini/rtsw/iocs/gnirsdc-data-manager/gnirsdc-dev bash -l
   ```

   This command starts an interactive container with the current directory mounted as the `/work` directory.

3. **Run the TCS Simulator:**
   Inside the GNIRSDC development container, start the TCS (Telescope Control System) simulator:

   ```bash
   python3 test/tcs_simulator.py
   ```

4. **Start the GNIRSDC Data Manager:**
   In the same container, run the GNIRSDC Data Manager in debug mode:

   ```bash
   python3 src/gnirsdm.py --debug --top tgnirs
   ```

   Before running this command, you need to set up the GIAPI-GLUE environment:

   ```bash
   cd giapi-glue-cc
   source defineGiapiglueEnv.sh
   cd ..
   ```

5. **Launch the System Manager Server:**
   Finally, start the System Manager Server in debug mode:

   ```bash
   python3 src/system_manager_server.py --debug
   ```

By following these steps, you'll have a complete debug environment set up with the GMP server, TCS simulator, GNIRSDC Data Manager, and System Manager Server all running in their respective containers or processes.

