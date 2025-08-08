## GNIRS GIAPI Integration (gnirsgiapi.py)

This document explains the GIAPI integration used by the GNIRS DC/DM system, implemented in `src/gnirsgiapi.py`. It covers environment requirements, library loading via `cppyy`, event posting, command subscriptions, GMP health checks, and known caveats for maintainers.

### Purpose
- Provide a thin Python bridge to GIAPI Glue-CC (C++) using `cppyy`.
- Post GIAPI observation lifecycle events (OBS_PREP, OBS_START/END_ACQ, OBS_START/END_READOUT, OBS_START/END_DSET_WRITE).
- Optionally subscribe to GIAPI sequence commands via the example `InstCmdHandler` callback (currently used for diagnostics).
- Verify GMP service availability at startup.

### Environment and Dependencies
- Requires GIAPI Glue-CC runtime tree and dependencies (ActiveMQ-CPP, log4cxx, APR, curlpp, expat).
- Environment variables (set by container `entrypoint.sh` via `giapi-glue-cc/defineGiapiglueEnv.sh`):
  - `GIAPI_ROOT`: Root of the GIAPI Glue-CC installation.
  - `LD_LIBRARY_PATH`: Must include GIAPI and third-party libs under `GIAPI_ROOT`.
- Python packages: `cppyy` is used to bind C++ includes/libraries at runtime.

On import, the module:
- Prints `GIAPI_ROOT` and `LD_LIBRARY_PATH` for diagnostics.
- Adds library/include search paths under `GIAPI_ROOT`:
  - Libraries: `external/curlpp/lib64`, `install/lib`, `external/log4cxx/lib`, `external/activemq-cpp/lib`, `external/apr/lib`, `external/apr-util/lib`.
  - Includes: `install/include` and the example headers path `src/examples/InstrumentDummyPython`.
- Loads C++ libraries by name: `libapr-1.so.0`, `libexpat.so.0`, `libaprutil-1.so.0`, `liblog4cxx.so.11`, `libactivemq-cpp.so.14`, `libgiapi-glue-cc`.

If `GIAPI_ROOT` is not set or paths are incorrect, `cppyy` will fail to locate headers/libraries. Always ensure the environment is prepared before importing/starting the IOC.

### Module API

#### GMP health checks
- `check_gmp(gmp_host='localhost', gmp_port=8008)`:
  - Attempts a TCP connection to the provided host/port (default 8008) with 5s timeout.
  - Logs at custom levels (via shared logging config). Raises on failure.
- `check_gmp_and_exit(gmp_host='localhost', gmp_port=8008)`:
  - Retries `check_gmp` up to 10 times with 1s delay; exits the process if unavailable.
  - Used by `gnirsdm.py` at startup to gate the IOC.

#### GiapiInterface
Creates a GIAPI bridge instance and subscribes to sequence commands.

- Constructor:
  - `__init__(self)`: Initializes and stores a C++ `InstCmdHandler` created with `self.giapiCallback`, then calls `subscribeCommands()`.

- Command subscription:
  - `subscribeCommands(self)`: Subscribes to GIAPI `TEST`, `REBOOT`, `INIT`, `APPLY`, `OBSERVE`, `ABORT` on `SET_PRESET_START` (or `SET_PRESET` for APPLY), binding to the provided C++ handler.
  - Note: Subscriptions rely on the GIAPI Glue-CC environment and an operational GMP/Instrument Services stack.

- Observation events (posted via `giapi.DataUtil.postObservationEvent`):
  - `observePrep(self, data_label)` → `OBS_PREP`
  - `observeStartAcq(self, data_label)` → `OBS_START_ACQ`
  - `observeEndAcq(self, data_label)` → `OBS_END_ACQ`
  - `observeStartReadout(self, data_label)` → `OBS_START_READOUT`
  - `observeEndReadout(self, data_label)` → `OBS_END_READOUT`
  - `observeStartWrite(self, data_label)` → `OBS_START_DSET_WRITE`
  - `observeEndWrite(self, data_label)` → `OBS_END_DSET_WRITE`
  - All event helpers call `handle_observation_event(event, description, label)` which posts and prints success/error.

- TCS context helpers (optional/testing):
  - `getTCSContext(self)`: Allocates a `giapi.TcsContext` and fills it via `giapi.GeminiUtil.getTcsContext(ctx, 1000)`.
  - `printTCSContext(self, ctx)`: Dumps selected fields for diagnostics.

- Command callback:
  - `giapiCallback(self, action_id, seq_cmd, activity, config)`: Intended to handle subscribed GIAPI commands.
  - Warning: The current implementation contains example/demo code referencing undefined attributes (`actRequested`, `dc_core_busy`, `DCS_CNT`, etc.). Treat as placeholder. It is not used by the operational paths that just post observation events.

### How it is used in the system
- `src/gnirsdm.py` instantiates `GiapiInterface` as part of the IOC:
  - At exposure time (in `src/gnirssdsu.py`), observe CAD calls `observePrep/StartAcq/EndAcq/StartReadout/EndReadout` based on readout lifecycle and the IOC `archive_fits` PV.
  - During FITS write (in the data manager processing flow), `OBS_START_DSET_WRITE`/`OBS_END_DSET_WRITE` are posted around FITS generation.
- GMP availability is checked at IOC startup to fail fast if services are down.

### Operational notes
- Verify environment:
  - `GIAPI_ROOT` must be set and correct.
  - `LD_LIBRARY_PATH` must include GIAPI and deps. In containers, this is handled by `entrypoint.sh` and `defineGiapiglueEnv.sh`.
- Connectivity:
  - `check_gmp_and_exit(GMP_HOST, GMP_TEST_PORT)` ensures GMP is reachable (host/port from `conf/gnirsdc/config.ini`).
- Error handling:
  - `postObservationEvent` returns a C++ status; errors are printed to stdout.
  - Exceptions from `cppyy` are caught and printed; consider integrating with the shared logging framework if needed.

### Known limitations / caveats
- `giapiCallback` includes a large commented/example block and active code paths referencing undefined members; it is not production-ready and should be treated as scaffolding.
- The module prints diagnostics at import time; noisy logs are expected if environment variables are missing.
- Event message strings (e.g., "Start Dest Write") are human-readable only; GIAPI consumers rely on event enums, not the strings.
- Subscription usage requires the underlying C++ GIAPI stack and broker configuration; this module does not manage broker connectivity beyond posting events.

### Minimal test (developer)
Within an environment where GIAPI Glue-CC is available and GMP is up:

```bash
python3.9 -c "from gnirsgiapi import GiapiInterface; g=GiapiInterface(); g.observePrep('test_label'); g.observeStartReadout('test_label'); g.observeEndReadout('test_label')"
```

If successful, you should see printed confirmations for each event. For full-system tests, use the IOC (`gnirsdm`) and exercise observe and FITS write flows.

### Related files
- `src/gnirsgiapi.py`: This module.
- `entrypoint.sh`: Sources GIAPI env and launches the IOC.
- `conf/gnirsdc/config.ini`: Supplies `GMP_HOST`/`GMP_TEST_PORT` and logging configuration.
- `src/gnirssdsu.py`: Calls into `GiapiInterface` during observe.
- `src/gnirsdm.py`: Posts dataset write events during FITS processing. 