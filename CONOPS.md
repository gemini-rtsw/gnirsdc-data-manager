## GNIRS Data Manager – Operator CONOPS

This document describes normal operations and procedures for GNIRS Detector Controller (DC) and Data Manager. It is intended for observatory operators and support staff.

### Audience and scope
- Operators running GNIRS DC, acquiring data, monitoring health, and retrieving FITS.
- Does not cover code development. For maintainer docs, see `README.gnirsdm.md`, `README.gnirssdsu.md`, and `README.gnirsgiapi.md`.

### System overview
- **DC container (`gnirsdc`)**: Runs the EPICS IOC, controller interface, file monitor, and FITS processing.
- **GMP container (`gmp`)**: Provides GIAPI services for status/events integration.
- **System Manager**: Web UI for monitoring, control, logs, and FITS file access.
- **Data paths**:
  - `/readout_data/new` → raw incoming (internal)
  - `/readout_data/fits` → final FITS output
  - `/staging/perm` → staging/archival area
  - `/readout_data/logs/irdc.log` → primary log file

### Prerequisites and access
- Your user must be in the `docker` group on the IRDC server.
- System Manager must be run as `telops`.
- System Manager URL (default): `http://<irdc-host>:8080`

### System Manager pages and controls
Use these pages for all routine operations. Indicators and controls mirror EPICS PVs and automate host commands where needed.

- Monitoring
  - Status: Heartbeat, DC State, Epics Top, GDS (GMP) connection, TCS connection, Temperature, SDSU Initialized, Interlock state, Bias voltage, NTP Time, Firmware checksum.
  - Actions:
    - Initialize SDSU Controller → initializes the controller (Apply flow)
    - Activate/Deactivate SDSU Voltages → power rails on/off
    - Clear Errors → preset Apply to clear error state
    - TDL → run TDL action
    - Start/Restart DC Software (Normal/Debug) → starts services on the host
    - Stop Controller → stops services
  - Integration Parameters: Fowler, Digital Averages, Exposure Time, Coadds, Sequence, File Name, Bias (DEEP/SHALLOW)
  - Run: Set Parameters, Start Integration / Abort
  - Logs: live PV log and file log viewer

- Engineering
  - Toggle temperature interlock override (use only with authorization)
  - Disk space (df -h) and directory sizes for `/readout_data/*` (du -sh)

- FITS Files
  - Browse recent FITS in `/readout_data/fits` and `/staging/perm`
  - Filter by date; download filtered set as ZIP
  - View FITS primary header for quick inspection

- Preview Latest
  - Live preview (PNG) of most recent FITS file in `/readout_data/fits`

- Config Editor
  - Edit `conf/gnirsdc/config.ini` (`DEFAULT` and `DEBUG` sections)
  - Save preserves key casing and alignment
  - Restart controller from Monitoring → Actions to apply changes

- Logs
  - List and view contents of files under `/readout_data/logs`

- Help
  - Renders repository `README.md` with a table of contents

### Normal operations

#### 1) Start the System Manager
- As `telops` on the IRDC host:
  ```bash
  dc-system-manager.sh
  # or debug mode (for testing per instruction)
  dc-system-manager.sh --debug
  ```
- Open the UI at `http://<irdc-host>:8080`.
- Note: Once System Manager is running, all controller operations are performed from the UI. The `dc-start/stop/status` scripts are for troubleshooting only.

#### 2) Start the Controller from the UI
- In Monitoring:
  - Use “Start Controller” (Normal or Debug as directed). The UI will start the required services and subscribe to PVs.
  - Wait for status indicators to populate.

#### 3) Verify health in the UI (Monitoring tab)
- Confirm:
  - Heartbeat is toggling
  - GMP status is Connected
  - TCS connection is Connected
  - SDSU state shows initialized/ready
  - Temperature interlock is not tripped

#### 4) Initialize the controller
- Click “Initialize Controller” (runs SDSU init and apply).
- Apply TDL if requested; Power On as required by procedure.
- Monitor logs and SDSU state for success.

#### 5) Configure integration parameters
- Set Fowler reads (lnrNum), digital averages, integration time, coadds, sequence count, and file label.
- Select bias (0.3 V shallow / 0.6 V deep) per plan.
- Do not override the temperature interlock unless explicitly authorized.

#### 6) Start an exposure sequence
- Click “Start Integration.”
- Observe progress (readout flag, progress, time-left) and logs.

#### 7) Inspect output
- FITS tab: browse readout/staging directories, view headers, or download.
- Preview tab: shows quicklook of the latest FITS if available.

#### 8) Stop the Controller
- Use the UI “Stop Controller” when operations complete.
- Only use CLI scripts for troubleshooting per the section below.

### Engineering operations
- Bias voltage: Use the Monitoring control to toggle between shallow (0.3) and deep (0.6) well depth.
- Power control: Use “Power On/Off.” Only after successful init and per procedures.
- Interlock override: Engineering tab toggle. Use only with explicit authorization; overriding can damage the detector.

### Data access
- Direct paths:
  - Final FITS: `/readout_data/fits`
  - Staging: `/staging/perm`
  - Logs: `/readout_data/logs/irdc.log`
- SCP example:
  ```bash
  scp <user>@<irdc-host>:/readout_data/fits/*.fits .
  ```
- UI download: Use FITS tab (date filters supported). You can preview and download headers and a ZIP of selected files.

### Routine maintenance tasks (operator)
- Update to current production images (requires restart to take effect):
  ```bash
  dc-production.sh
  dc-stop.sh && dc-start.sh
  ```
- Update to latest images (testing only, as directed):
  ```bash
  dc-latest.sh
  dc-stop.sh && dc-start.sh
  ```
- Promote current to production (release operation; coordinate with software):
  ```bash
  dc-promote.sh
  ```
- Start only the GMP service (rare; for diagnostics):
  ```bash
  dc-start-gmp.sh
  ```

### Troubleshooting
- System Manager doesn’t open:
  - SSH to the IRDC host and run `dc-system-manager.sh` as `telops`.
  - Confirm no firewall or port conflicts on 8080.

- DC not running or unhealthy:
  - Prefer the UI controls first.
  - If needed, check scripts: `dc-status.sh`, `dc-start.sh`, `dc-stop.sh`.
  - Tail logs: `tail -f /readout_data/logs/irdc.log`.

- GMP shows disconnected in UI:
  - Verify via UI; if required, `dc-start-gmp.sh` or `dc-start.sh`.

- TCS connection shows disconnected:
  - Verify EPICS network reachability to TCS. Escalate to control systems if needed.

- Interlock prevents actions:
  - Check detector temperature. Do not override unless authorized.

- No FITS output after exposure:
  - Check logs for errors in FITS creation; verify disk space in Engineering tab.
  - Verify label/parameters and retry.

- UI values not updating:
  - Refresh Monitoring.
  - If persistent, restart System Manager: `dc-system-manager.sh`.

### Command reference
Note: These scripts are primarily for troubleshooting and maintenance. Normal operations are performed via the System Manager UI.

- `dc-start.sh [args]`: Start `gmp` and `gnirsdc` with current images. Passes extra args to DC.
- `dc-stop.sh`: Stop and remove `gnirsdc` and `gmp` containers.
- `dc-status.sh`: Show running container status and `docker ps`.
- `dc-system-manager.sh [--debug]`: Start System Manager (requires `telops`).
- `dc-production.sh`: Pull production images and retag as `current` (restart required).
- `dc-latest.sh`: Pull latest images and retag as `current` (restart required).
- `dc-promote.sh`: Archive current production and promote `current` to `production`.
- `dc-start-gmp.sh`: Start only the `gmp` container.

### Safety notes
- Temperature interlock protects the detector; do not disable unless directed by engineering.
- Bias changes affect detector operating point; adjust only per observing plan or engineering instruction.
- Keep an eye on disk usage; ensure `/readout_data` and `/staging/perm` have space before long runs.

### GNIRS WCS Procedures (operator summary)
- WCS files live on pisces under `/gemini/GEM5/gnirs/DC/DC/data/` (e.g., `gnirs_3_short.wcs`). Track changes per local instrument procedures.
- Typically check WCS for GNIRS short blue camera.

Astrometric field method (preferred when many stars):
1) Choose a field with a bright central star and many Gaia/2MASS stars
2) Confirm science fold values; slew to field
3) Perform GNIRS hotspot and refine IAA as needed
4) Take an image; run gwcs to derive new WCS (IAA output gives WCS dX/dY)
5) If within ~1–2 arcsec, keep; otherwise adjust WCS (below)
6) Upload updated WCS to `/gemini/GEM5/gnirs/DC/DC/data/`
7) Reload WCS (DC Additional Screens → initWcsCAD), take a verification image and re-run gwcs

Adjusting WCS with shiftwcs.sh (pixels or arcsec):
- On pisces:
```bash
/home/gemvx/bin/shiftwcs.sh [-p] wcsfile xshift yshift
```
- Script backs up the original automatically; `-p` uses pixel shifts (often more intuitive).

Single star offsets method (when <~9 stars available):
1) Use a single bright star; center on CR center while guiding
2) Execute ~10 offsets to field extremes, starting/ending at (0,0)
3) Record instrument offsets (X,Y) and image centroid (x,y) for each frame
4) Build raw table (image number, inst offsets, image coords), then convert to `.wcs` with awk:
```bash
awk '$1>0 {printf "%6.2f %6.2f  %8.4f %8.4f\n", $4,$5,$2/1.61144,$3/1.61144}' gnirs.raw > gnirs.wcs
```
5) Backup existing file and copy the new one:
```bash
mv gnirs_3_short.wcs gnirs_3_short.wcs.$(date +%Y%m%d)
scp gnirs.wcs gemvx@pisces:/gemini/GEM5/gnirs/DC/DC/data/gnirs_3_short.wcs
```
6) Reload WCS (initWcsCAD) and verify with a new image

Notes
- WCS depends on hotspot; large hotspot errors can cause gwcs failures—consider single-star method first.
- After uploading a new WCS, always reload (initWcsCAD) and reverify.
- See the “GNIRS WCS Procedures” section in `README.md` for full details and context.
