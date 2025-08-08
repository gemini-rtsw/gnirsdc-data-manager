## GNIRS SDSU Controller Subsystem (gnirssdsu.py)

This document is a maintainer-level guide to the GNIRS SDSU controller subsystem implemented in `src/gnirssdsu.py`. It covers the CAR/CAD/Apply command model, EPICS PVs, interlocks, exposure sequencing, TCS/WCS integration, and controller interactions.

### Purpose
- Expose EPICS PVs and CAD/CAR commands to configure and operate the SDSU ARC controller for GNIRS.
- Enforce temperature interlock safety.
- Integrate TCS context and select an appropriate WCS file.
- Coordinate GIAPI observation events during observe cycles (in conjunction with the `gnirsdm` IOC for data write events).

### Key Dependencies
- `libgnirsioc`: Native controller bindings (e.g., `controllerInterface`, `controllerInterfaceDebug`, `setGlobalDebug`).
- `pygeminirec`: Apply/CAD/CAR record implementations (`ApplyRecord`, `CADRecord`, `CARRecord`).
- `lakeshore.py`: Lakeshore 325 client for detector temperature and status.
- `tcs_monitor.py`: Collects EPICS-based TCS context and provides NTP time.
- `wcs_utils.py`: `choose_file(port, camera, ao)` to select WCS file based on the TCS context.
- `gnirsutil.py`: Provides config values (`TEMP_CON_IP`, `INTERLOCK_TEMP`, `DEBUG_MODE`, etc.).

### PV Group Structure
`GnirsCADCARController` (subgroup mounted under the main IOC) defines:
- CAR/CAD/Apply records for command orchestration.
- Operational PVs for exposure setup, progress, temperatures, interlock, and metadata.
- Background helpers: Lakeshore temperature monitor, TCS monitor, and controller instance.

Key subgroups and records:
- `applyC`: `CARRecord` at `dc:applyC.*`
- `apply`: `ApplyRecord` at `dc:apply.*` tying together CARS and CADs
- CADs: `TDL`, `bias`, `init`, `initSDSU`, `powerOn`, `powerOff`, `dcconfig`, `endObserve`, `abort`, `stop`, `observe`, with an additional `CARRecord` `observeC` for observe workflow

Record ordering (Apply → CADs):
- The `apply.cads.records` list enforces execution order. Note: `observe` appears twice; this mirrors an existing ordering workaround.

### CAD Implementations
All CADs inherit from `GnirsCAD`, which:
- Binds to the top-level `GIAPIInterface` as `self.giapi` and `logMessage` callback from the parent IOC.
- Provides a `controller` property proxying `parent.sdsuController`.

Implemented CADs and their semantics:
- `InitCAD`: No-op placeholder; logs "Init successfull".
- `TDLCAD`: Tests data link via `controller.testDataLink()`.
- `BiasCAD`: Sets detector bias:
  - `arSetupH == "0.3"` → `controller.biasLow()` (labeled "shallow: 400mv, -3.6").
  - `arSetupH == "0.6"` → `controller.biasMed()` (labeled "deep: 600mv, -3.4").
  - Any other value logs an error and fails.
- `InitSDSUCAD`: Full SDSU initialization with interlock enforcement:
  - If `interlocked()` returns true, denies init ("Detector not at temperature").
  - Calculates and publishes firmware checksum (`firmChecksum`) for `firmware/AladdinIII_SDSU_Firmware.lod`.
  - Calls `setGlobalDebug(DEBUG_MODE)`, constructs `controllerInterface("/readout_data", firmware_path)`, sets AladdinIII, tests data link, and calls `init()`.
  - On success, writes `sdsuState="INITIALIZED"` and messages; on errors, cleans up the controller and reports.
  - Notes: A disabled debug branch using `controllerInterfaceDebug()` exists in comments.
- `PowerOnCAD` / `PowerOffCAD`: Guarded by controller presence and interlock; call `controller.powerOn()`/`controller.powerOff()`.
- `DCConfigCAD`: Sends exposure parameters to the controller: `setExposure(lnrNum, digitalAvgs, exposureTime, coaddsVAL, dropReadoutsNum, observeA)`.
- `AbortCAD`: Calls `controller.abortExposure()` and sets `sequence_abort = True` to stop ongoing readout/sequence.
- `StopCAD`: Trivial CAD that writes a message only (currently maps `stop` to `AbortCAD` in the subgroup).
- `ObserveCAD`:
  - Guards: controller present, not interlocked, not currently reading out (`rdout == 0`).
  - If `sequence > 1`, auto-enables timestamp labeling (`labelTimeStamp=1`).
  - Loops for `sequence` exposures, optionally appending a unique `timestamp` to `observeA` when labeling is enabled.
  - If `archive_fits == 0`, appends `.fits` extension to `observeA` to avoid archiving side-effects.
  - Calls `setBias()`, pushes config to controller, sets `rdout=1`, starts a countdown timer task based on `controller.getExposureDelay(...)`, then runs `start_async_exposure()`.
  - On completion, updates progress PVs, decrements `sequenceLeft`, resets sequence-related PVs (sequence to 1, disables `labelTimeStamp`, clears `include_eng`, sets `archive_fits=1`), and strips `.fits` from `observeA`.

`start_async_exposure()` details:
- If `archive_fits`, emits GIAPI events: `observePrep`, `observeStartAcq`, `observeEndAcq`, then `observeStartReadout` before initiating SDSU readout.
- Obtains a TCS context via the TCS monitor and sets it in the controller (`controller.setTCSContext(tcs_context)`), writing the chosen `wcs_file` PV.
- Starts the exposure via `controller.startExposure(detectorTemp1, detectorTemp2, include_eng)` and polls `controller.getReadingOut()` in a background thread until complete.
- If `archive_fits`, emits `observeEndReadout` at the end.

### Temperature Interlock
- Lakeshore 325 provides detector temperature reading (`temperature`) and a text `temperature_status`.
- `INTERLOCK_TEMP` from config guards against unsafe operation. Interlock condition is true when `(temperature > INTERLOCK_TEMP or temperature == -999)` and `disable_interlock == 0`.
- Many CADs short-circuit with a "Detector not at temperature" message if interlocked.

### TCS and WCS Integration
- `TCSMonitor` runs in the background reading configured PVs (`TCS_PREFIX`, `AG_PREFIX`, `CC_PREFIX`) and provides a `TCSContext` struct to the controller.
- `get_wcs_context()` selects a WCS file via `choose_file(port, camera, ao)` and writes the IOC `wcs_file` PV.
- `ntp_time` PV scans at 10 Hz providing current MJD (from TCSMonitor or system time as fallback).

### Important PVs (selected)
- Configuration and command:
  - `dc:lnrNum` (int): Low-noise reads (Fowler pairs).
  - `dc:digitalAvgs` (int): Digital averages per Fowler sample.
  - `dc:integTime.VAL` (double): Exposure time.
  - `dc:coadds.VAL` (double): Number of coadds.
  - `dc:dropReadoutsNum` (int): Number of initial readouts to discard.
  - `dc:readUpTheRamp` (int): Enable read-up-the-ramp mode (informational currently).
  - `dc:arSetup.H` (string): Bias selection; "0.3" shallow or "0.6" deep.
  - `dc:dcconfig.*`: CAD to push configuration to the controller.
  - `dc:observe.*` / `dc:observeC.*`: Observe CAD and related CAR.
  - `dc:abort.*`, `dc:endObserve.*`, `dc:stop.*`: Abort/stop control.
- Sequence and progress:
  - `dc:sequence` (int) with `dc:sequenceLeft` (long).
  - `dc:labelTimeStamp` (long): Adds timestamp to labels when > 0.
  - `sad:dc:rdout` (long): Readout in progress (1/0).
  - `sad:dc:timeLeft` (string): Seconds remaining (updated at 10 Hz during readout).
  - `sad:dc:obsProgress` (double): Exposure percent complete.
  - `sad:dc:coaddProgress` (double): Coadd progress percent.
- Temperatures and interlock:
  - `dc:temperature` (double, RO): Current detector temp (Lakeshore).
  - `dc:temperature_status` (string): Truncated (40 chars) status string.
  - `dc:disable_interlock` (int): Bypass interlock when > 0.
  - Interlock method: `interlocked()` helper.
- Metadata:
  - `dc:dataLabel` (string): Exposure label (also set via `observeA` putter).
  - `dc:observe.A` (string): Primary label PV; its putter marks `observe` CAD to run.
  - `dc:firmChecksum` (string): MD5 of firmware .lod; calculated at startup and during initSDSU.
  - `dc:sdsuState` (string): Controller state.
  - `dc:wcs` (string): WCS file (top-level IOC PV `wcs_file` is also updated).
  - `sad:dc:detID.VAL`, `sad:dc:detType.VAL`, `sad:dc:obsepoch`: Placeholders.

### Controller Interface Usage
- `controllerInterface(base_path, firmware_path)` constructs the controller; set debug with `setGlobalDebug(DEBUG_MODE)`.
- Essential calls used here:
  - `setAladdinIII(True)`
  - `init()`, `powerOn()`, `powerOff()`, `abortExposure()`
  - `testDataLink()`, `setExposure(lnr, ndavg, exptime, coadds, drop, label)`
  - `getExposureDelay(exptime, lnr, ndavg)`
  - `startExposure(temp1, temp2, include_eng)`
  - `getReadingOut()` (polled via `asyncio.to_thread`)
  - `setTCSContext(context)`

### GIAPI Events
- During observe when `archive_fits == 1`, this module sends:
  - `observePrep(label)`
  - `observeStartAcq(label)` → `observeEndAcq(label)`
  - `observeStartReadout(label)` → later `observeEndReadout(label)`
- Data write events (`OBS_START_DSET_WRITE` / `OBS_END_DSET_WRITE`) are emitted by the data manager (`gnirsdm.py`) when FITS files are being written.

### Operational Runbook
- Initialize controller: `dc:initSDSU.start` (ensure interlock is not active; firmware checksum is published).
- Power sequence: `dc:powerOn.start` / `dc:powerOff.start` after init.
- Configure exposure: Set `dc:lnrNum`, `dc:digitalAvgs`, `dc:integTime.VAL`, `dc:coadds.VAL`, etc., then `dc:dcconfig.start`.
- Set label: Write to `dc:observe.A` (this will mark the observe CAD). Ensure `archive_fits` on the parent IOC is set as desired.
- Start observe: `dc:observe.start` via the apply flow; monitor `sad:dc:rdout`, `timeLeft`, `obsProgress`, and `coaddProgress`.
- Abort: `dc:abort.start` to abort exposure and sequence.

### Known Limitations / Notes
- `BiasCAD` error branch logs `biasVal` which may be undefined in that scope; adjust to avoid NameError.
- `apply.cads.records` contains `observe` twice to work around ordering; validate as needed when changing record sets.
- Interlock default temp value of `-999` triggers interlock until a valid temperature is read; this is intentional but can be confusing in tests.
- `StopCAD` is implemented but `GnirsCADCARController.stop` currently maps to `AbortCAD`.
- `InitCAD` placeholder returns success without hardware actions.

### Extending or Modifying
- Add new CADs by subclassing `GnirsCAD` and wiring them into `GnirsCADCARController` as subgroups, then update `apply.cads.records` order.
- To change interlock policy, edit `interlocked()` and temperature PV update cadence.
- To adjust WCS selection, modify `wcs_utils.choose_file(...)` and the `get_wcs_context()` flow.
- For new controller features, extend `libgnirsioc` and call into the new methods from CAD logic.

### Key Files
- `src/gnirssdsu.py`: This controller PV group and CAD implementations.
- `src/tcs_monitor.py`: TCS context and NTP time provider.
- `src/lakeshore.py`: Lakeshore 325 driver.
- `src/wcs_utils.py`: WCS file selection heuristics.
- `src/gnirsdm.py`: Parent IOC that mounts this subgroup and coordinates data flow. 