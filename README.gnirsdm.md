## GNIRS Data Manager IOC (gnirsdm)

This document is a maintainer-level guide to the GNIRS Data Manager IOC implemented in `src/gnirsdm.py`. It covers architecture, configuration, runtime behavior, EPICS PVs, and operational runbooks.

### Overview
- **Purpose**: Watch for newly acquired GNIRS raw data, convert it to FITS, publish status via EPICS PVs, and emit GIAPI observation events to GMP.
- **Key Technologies**: Python 3.9, Caproto (EPICS IOC), asyncinotify (file system events), multiprocessing, Astropy (FITS), cppyy + GIAPI glue-cc (GIAPI), Numpy.
- **Entry point**: `src/gnirsdm.py` (also launched in containers via `entrypoint.sh`).

### High-level Architecture
- **IOC**: `GnirsDataManagerIOC` defines PVs for health, heartbeat, data_dir, state, logging, etc. It embeds:
  - `CADInterface`: CAR/CAD controller subgroup for GNIRS (from `gnirssdsu.py`).
  - `GIAPIInterface`: GIAPI integration (`gnirsgiapi.py`) for observation events.
  - `DiskSpaceMonitor`: PVs for disk usage (from `diskSpaceMonitor.py`).
- **File monitor**: `asyncinotify` watches `<data_dir>/new` for `CLOSE_WRITE|MOVED_TO` events and enqueues new `.header` files for processing.
- **Processor**: `GnirsDataManagerProcessor` consumes a queue of tasks and spawns a separate `multiprocessing.Process` per file, isolating CPU work and guarding the IOC loop.
- **Conversion**: `manager.DataProcessor` reads JSON headers and raw frames, unscrambles and combines samples into science and optional engineering FITS HDUs, writes to `<data_dir>/fits`, and cleans up raw files.
- **GIAPI events**: When a file is being written, the processor emits `OBS_START_DSET_WRITE` and `OBS_END_DSET_WRITE` with the data label derived from the header (`header['PDU']['LABEL']`).
- **Logging**: A shared logging subsystem (`logging_config.py`) forwards messages to both console/file and the IOC `log_message` PV via a custom handler.

### Process and Data Flow
1. On startup, config is loaded from `conf/gnirsdc/config.ini` (see Configuration). EPICS CA address list is set from config, and GMP availability is verified before continuing.
2. The IOC starts on ports 5064/5065 and publishes PVs under the configured prefix (default `nirs:` or `tgnirs:` in debug).
3. The monitor pre-scans `<data_dir>/new` and enqueues existing `.header` files.
4. For each queued file:
   - The standalone child process decodes the header, extracts `LABEL`, signals GIAPI `OBS_START_DSET_WRITE`, calls `DataProcessor.process_file(...)`, and finally signals `OBS_END_DSET_WRITE`.
   - The main process updates IOC PVs (`currentLabel`, `state`, logs) and cleans finished child processes.
5. `DataProcessor` writes the FITS to the processing area first, then moves it to the output directory (`<data_dir>/fits` by default), and removes or retains raw files based on `keep` (default: delete).

### Configuration
- **File**: `conf/gnirsdc/config.ini` with `DEFAULT` and `DEBUG` sections.
- **Runtime selection**: `--debug` CLI or `DEBUG_MODE` in config chooses which section (`DEBUG` vs `DEFAULT`) is used. CLI flag overrides config.
- **Key options** (by section):
  - `INSTRUMENT_NAME`: e.g., `GNIRS`
  - `DEFAULT_PREFIX`: base EPICS prefix without trailing colon (e.g., `nirs`, `tgnirs`)
  - `TCS_PREFIX`, `AG_PREFIX`, `CC_PREFIX`: external PV roots
  - `DEFAULT_DATADIR`: root for data directories (e.g., `/readout_data`)
  - `MAX_LOG_SIZE`: number of log lines retained in `log_array` PV
  - `GMP_HOST`, `GMP_PORT`, `GMP_TEST_PORT`: GMP connectivity
  - `LOG_LEVEL`, `CONSOLE_LEVEL`, `LOG_FILE`, `LOG_ROTATE_TIME`: logging
  - `EPICS_CA_ADDR_LIST`: space-separated CA addresses
- **Environment**:
  - `EPICS_CA_ADDR_LIST` is set from config on startup.
  - `GIAPI_ROOT` and `LD_LIBRARY_PATH` are used by GIAPI glue; in containers they are configured by `entrypoint.sh` via `giapi-glue-cc/defineGiapiglueEnv.sh`.
  - On startup, the code inspects Git repos at `/gnirsdc`, `/pycadcar`, and `/gnirsdc-lib`. It logs commit info and exports `DC_COMMIT` and `LIB_COMMIT` for FITS headers.

### Command-line Interface
Invoked directly or by the container entrypoint:

```bash
python3.9 src/gnirsdm.py \
  --data-dir /readout_data \
  --output-dir /readout_data/fits \
  --top nirs \
  [--debug]
```

- **--data-dir/-d**: Base data path. The IOC watches `<data-dir>/new` and populates `<data-dir>/processing`, `<data-dir>/fits`, `<data-dir>/error`, `<data-dir>/processed_raw` as needed.
- **--output-dir/-o**: FITS output directory. Defaults to `<data-dir>/fits`.
- **--top/-t**: EPICS top (prefix root). Final prefix is `<top>:`. Overrides `DEFAULT_PREFIX`.
- **--debug/-D**: Enable debug config section and verbose logging.

### Directory Layout and File Semantics
- `<data_dir>/new`: Incoming raw data. A file is considered ready when its `.header` partner exists. Raw samples may be stored as `*-<coadd>.frame.<n>`.
- `<data_dir>/processing`: Staging area while processing.
- `<data_dir>/fits`: Destination for completed FITS files (or the directory set via `--output-dir`).
- `<data_dir>/error`: Files that failed processing (headers and frames).
- `<data_dir>/processed_raw`: If `keep=True`, raw files are moved here after FITS generation; otherwise they are deleted.

### EPICS PVs
Prefix is `<DEFAULT_PREFIX or --top>:`. Selected PVs:

- **health** (string): Overall health; set to "GOOD" at startup; set to "BAD" on TCS disconnects.
- **sad:dc:heartBeat** (int): 0/1 toggling every 0.5 s.
- **tcs_connection** (string): "CONNECTED"/"DISCONNECTED". Uses CAPROTO sync client to read `<TCS_PREFIX>heartbeat` every second.
- **uptime** (int): IOC uptime in seconds.
- **instrument** (string, readonly): From config `INSTRUMENT_NAME`.
- **gmp_status** (string, readonly): "CONNECTED"/"DISCONNECTED"; scans every 5 s using `check_gmp()`.
- **wcs_file** (string): Name of selected WCS file; logs any change.
- **state** (mbbo/intended): Intended states are BOOTING, INITIALIZING, RUNNING, PROCESSING. The IOC toggles state during queue processing.
- **currentLabel** (string): Label of the image currently being processed.
- **lastError**, **lastErrorLabel** (string): Last error and the associated label.
- **lastProcessed** (string): Name of last processed image.
- **log_message** (string): Last log message; synchronized with the logging backend.
- **log_datetime** (string): Timestamp of `log_message` (YYYY-MM-DD HH:MM:SS).
- **log_array** (string[], max `MAX_LOG_SIZE`): Rolling log buffer.
- **queued** (int): Queue length estimate; increments/decrements with tasks.
- **include_eng** (int): If non-zero, include engineering frames in FITS (per `manager.save_processed_image`).
- **log_level** (enum): One of `DEBUG, INFO, WARNING, ERROR, CRITICAL`. Adjusts the custom log handler level and posts a log message indicating the change.
- **archive_fits** (int): Placeholder PV for archiving behavior (not enforced in processing path).
- **data_dir** (string): Effective data directory.
- **restart_ioc** (int): Intended to restart the IOC on write=1. Note: the current implementation references undefined globals and is not production-ready.

### GIAPI Integration
- Implemented in `src/gnirsgiapi.py` using `cppyy` bindings to GIAPI glue-cc.
- On data write lifecycle, the IOC emits:
  - **OBS_START_DSET_WRITE** via `observeStartWrite(label)` when FITS writing begins.
  - **OBS_END_DSET_WRITE** via `observeEndWrite(label)` when FITS writing completes.
- Connectivity check to GMP is performed at startup; the process exits if unreachable after retries.

### Data Processing Details
- Header is JSON (`<base>.header`). Processing errors move files to `error`.
- Frames: expected pattern `'<raw_path>-<coadd>.frame.<n>'` covering reference and signal reads, with coaddition support.
- Sample handling and unscrambling in `manager.py`:
  - Generates SCI image; optionally appends ENG extensions per read.
  - Uses `gnirssdsu.Processor` pipelines (`unscramble`, ADS averaging) with shape conventions described in code.
  - FITS naming and header construction via `fits_header_definitions.define_hdu_list(...)` and `generate_new_filepath(...)` if conflicts occur.
- By default, raw files are deleted after successful FITS creation (`keep=False` in IOC). Change behavior by instantiating `DataProcessor(..., keep=True)` if needed.

### Running in Containers
- See the existing root `README.md` for container lifecycle scripts (`dc-start.sh`, `dc-stop.sh`, `dc-status.sh`) and the `gnirsdc-system-manager` service.
- The gnirsdm container entrypoint (`entrypoint.sh`) performs:
  - `source giapi-glue-cc/defineGiapiglueEnv.sh` to set GIAPI env.
  - `python3.9 src/gnirsdm.py --top nirs` (plus any extra args passed to the container).

### Running Locally (developer)
- Python 3.9 with system access to GIAPI glue-cc libraries (set `GIAPI_ROOT` and `LD_LIBRARY_PATH`).
- EPICS networking configured (e.g., `EPICS_CA_ADDR_LIST` to reachable CA servers, or rely on config.ini).
- Install Python dependencies (inside dev container or system env) and run:

```bash
python3.9 src/gnirsdm.py --top tgnirs --data-dir /readout_data --debug
```

- Create the expected directories and seed test files:
```bash
mkdir -p /readout_data/{new,processing,error,processed_raw,fits}
# Copy or generate <base>.header and corresponding raw *frame* files into /readout_data/new
```

### Logging
- Config-driven console/file levels; file rotates daily at `LOG_ROTATE_TIME` local hour, keeping 7 days (`/readout_data/logs/irdc.log` by default).
- The IOC mirrors log messages to PVs (`log_message`, `log_array`) via a custom handler wired at IOC startup.
- Adjust verbosity at runtime via the `log_level` PV.

### TCS and External PVs
- A background thread checks TCS connectivity by reading `<TCS_PREFIX>heartbeat`. On disconnect, IOC `health` flips to BAD, and a log is emitted.
- `tcs_monitor.py` provides an auxiliary TCS context collector using `pyepics` (not directly wired into `gnirsdm.py` yet) and `libgnirsioc`.

### Ports and Networking
- IOC listens on TCP 5064 and UDP 5065 by default (standard EPICS). Ensure container host networking or explicit port maps allow CA clients to connect.
- GIAPI connectivity requires GMP host/port reachability.

### Known Limitations / Notes
- **restart_ioc PV**: Current implementation refers to `proc`/`thrd` variables not in scope; not production-ready.
- **State machine enum**: `StateEnum` intends BOOTING, INITIALIZING, RUNNING, PROCESSING states; verify enumeration values if adjusting code.
- **Error handling**: Failures during FITS write or moves are routed to `error` and surfaced via `lastError`/logs.
- **EPICS_CA_ADDR_LIST**: Is set at process start from config; subsequent config changes require restart.

### Extending the IOC
- Add PVs by extending `GnirsDataManagerIOC` with new `pvproperty` definitions.
- To hook new logging sinks, use `logging_config.set_log_message_func` with an asyncio-event-loop-aware callback.
- To change FITS content, modify `manager.define_hdu_list` and `manager.save_processed_image` and ensure headers are consistent.
- To retain raw files, instantiate `DataProcessor` with `keep=True` in `main()` and/or expose a PV to toggle this at runtime.

### Relevant Files
- `src/gnirsdm.py`: IOC, inotify watcher, queue, and process orchestration.
- `src/manager.py`: Data movement, header parsing, raw-to-FITS conversion.
- `src/gnirsgiapi.py`: GIAPI integration and event posting; GMP checks.
- `src/logging_config.py`: Central logging config and PV integration.
- `src/gemUtilities.py`: EPICS CA channel reachability check.
- `src/diskSpaceMonitor.py`: Disk usage PVs.
- `conf/gnirsdc/config.ini`: Runtime configuration.
- `entrypoint.sh`: Container startup flow.

### Operational Runbook
- **Start**: Use `dc-start.sh` (see root `README.md`) or run `python src/gnirsdm.py ...` locally.
- **Verify**:
  - `health` PV is "GOOD"; `sad:dc:heartBeat` toggles.
  - `gmp_status` shows "CONNECTED"; `tcs_connection` shows "CONNECTED".
  - `data_dir` PV equals the expected path; directories exist.
- **Ingest test**: Drop a matching `<base>.header` and corresponding raw frames into `<data_dir>/new`. FITS should appear under `<output_dir>`.
- **Logs**: Tail `/readout_data/logs/irdc.log` and watch IOC PVs `log_message`/`log_array`.
- **Stop**: Use `dc-stop.sh` for containers. For local dev, Ctrl-C the process.

### Contact and Further Docs
- Use the existing root `README.md` for broader DC system scripts, container orchestration, and environment setup.
- This document focuses specifically on the `gnirsdm` IOC maintainership. 