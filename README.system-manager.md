## GNIRS System Manager – Engineering Guide (Architecture & Maintenance)

This document is for engineers maintaining the GNIRS System Manager web UI. It explains how the server works, page wiring, PV subscriptions, host command execution, and where to modify behavior.

### Code structure
- Server: `src/system_manager_server.py` (Flask app)
- Templates: `src/templates/*.html`
  - `base.html`: navigation and styling
  - `monitoring.html`: status, Actions, integration parameters, logs, SSE client
  - `engineering.html`: interlock, disk space, directory sizes
  - `fits_files.html`, `fits_header.html`: file list, header view
  - `preview.html`: latest FITS preview
  - `config_editor.html`: `config.ini` editor
  - `logs.html`: log file list
  - `readme.html`: renders `README.md`
- Static assets: `src/static/*` (referenced in `base.html`)

### Configuration and runtime
- Config: `conf/gnirsdc/config.ini` loaded at startup:
  - Two sections: `DEFAULT` and `DEBUG`
  - Keys used: `DEFAULT_PREFIX`, paths (`READOUT_DIR`, `STAGING_DIR`, `LOG_DIR`), logging, etc.
  - `config_mode` toggled by `--debug` flag at server start, or dynamically via `/start_controller` action to match controller mode
- Server start: `python3 src/system_manager_server.py [--debug] --port 8080`
  - Runs as the `gnirsdc-system-manager` systemd service (container runs as `telops`)
- Host commands: SSH to `localhost` with `/home/telops/.ssh/id_rsa` mounted into container (`--network=host`)

### EPICS connectivity
- Client libs: `caproto.threading.client.Context` for subscriptions and polling; occasional `epics.caput/caget` for actions
- PV subscription manager: `PVSubscriptionManager`
  - Subscriptions per prefix (top name): core PVs:
    - `:log_message`, `:sad:dc:heartBeat`, `:tcs_connection`, `:gmp_status`
    - `:dc:lnrNum`, `:dc:digitalAvgs`, `:dc:integTime.VAL`, `:dc:observe.A`, `:dc:temperature`, `:dc:disable_interlock`, `:dc:applyC.VAL`, `:dc:arSetup.H`, `:dc:sdsuState`, `:dc:coadds.VAL`, `:dc:sequence`, `:dc:firmChecksum`
    - `:sad:dc:rdout`, `:sad:dc:obsProgress`, `:ntp_time`
  - SSE broadcasting: `PVSubscriptionManager.broadcast_to_clients` JSON-serializes updates and pushes to connected clients via per-client queues
  - Health: `check_subscription_health()` periodically re-subscribes or rebuilds the context (`reinitialize_connections`) when a majority of PVs are disconnected
- Value formatting:
  - Enum mapping via metadata; bytes -> UTF-8 string; float precision via metadata; bias voltage derived from `:dc:arSetup.H`
  - `get_all_pvs()` returns a throttled snapshot plus connection flags per key PV

### Server-sent events (SSE)
- Endpoint: `/sse`
- Client: Monitoring page opens `EventSource('/sse')`
- Message types:
  - `{'connected': true}` → initial connection
  - `{'server_heartbeat': ts}` → periodic heartbeat when idle
  - PV update payloads (arbitrary fields like `heartbeat`, `tcs_connection`, `obsProgress`, `log_message`)
- Client logic:
  - `processUpdates(data)` handles PV updates; `updateObsProgress(rdout, progress)` drives progress bar and Start/Abort state.
  - Connection loss triggers exponential backoff reconnect.

### Actions and routes
- Controller lifecycle (over SSH to host):
  - `POST /start_controller` {mode: normal|debug} → runs `/usr/local/bin/dc-start.sh [--debug]`
    - Also updates `config_mode` and re-subscribes to the new `DEFAULT_PREFIX`
  - `POST /stop_controller` → `/usr/local/bin/dc-stop.sh`
- Observe flow (direct caput to PVs):
  - `POST /set_integration_params` → writes Fowler/digitalAvgs/integTime/observe.A/coadds/sequence
  - `POST /start_integration` → `:dc:observe.DIR=MARK`, `:dc:apply.DIR=START`
  - `POST /abort_integration` → `:dc:abort.DIR=MARK`, `:dc:apply.DIR=START`
- SDSU/ancillary:
  - `POST /initialize_sdsu` → `:dc:initSDSU.DIR=MARK`, Apply
  - `POST /power_on_cad` / `POST /power_off_cad` → `:dc:powerOn/Off.DIR=MARK`, Apply
  - `POST /apply_tdl` → `:dc:TDL.DIR=MARK`, Apply
  - `POST /clear_errors` → `:dc:apply.DIR=PRESET`
- Engineering:
  - `POST /toggle_interlock` → toggles `:dc:disable_interlock`
  - `GET /get_eng_info` → runs `df -h` and `du -sh /readout_data/*` via SSH and returns JSON
- Files/preview:
  - `GET /fits` → list FITS from `/staging/perm` and `/readout_data/fits` with optional date filters
  - `GET /download_fits` → ZIP filtered list and return
  - `GET /fits/<path>` → stream FITS
  - `GET /fits_header/<path>` → render primary header
  - `GET /preview_latest_fits[?info=true]` → PNG of latest FITS or JSON info
- Logs:
  - `GET /get_log_messages` → PV log deque (from `:log_message`)
  - `GET /get_file_log` → tail of `/readout_data/logs/irdc.log` (last 500KB)
- Config editor:
  - `GET /config` → render `DEFAULT` + `DEBUG`
  - `POST /save` → writes aligned config preserving key case and spacing via custom `AlignedCasePreservingConfigParser.write`

### Templates and UI wiring
- `base.html` defines the navigation and loads `static/css/style.css` (if present)
- `monitoring.html`:
  - Initializes SSE, throttled `/get_all_pvs` poll (~1s), and action handlers
  - Maps PVs to UI fields; handles enum/value formatting, progress bar state, and buttons
  - Two log panes (PV log via SSE, file log via REST)
- `engineering.html`:
  - Calls `/toggle_interlock`, `/get_eng_info` on a 1s interval; renders disk space and directory sizes
- `fits_files.html`:
  - Date filter + ZIP download; links to header view and FITS stream
- `preview.html`:
  - Polls preview image and info every 0.5s
- `config_editor.html`:
  - Displays editable tables for both sections in `config.ini`; submit to `/save`

### Host integration and security
- The System Manager container runs with:
  - `--network=host` and mounted `/home/telops/.ssh` (read-only)
  - User set to `telops` UID/GID to ensure file ownership and SSH access
  - `/etc/passwd`, `/etc/group`, `/etc/shadow` mounted read-only to match user
- `/usr/libexec/gnirsdc-data-manager/run-system-manager` (started by the service) runs the container as `telops` and adds localhost to its known_hosts

### Error handling and resilience
- SSE client auto-reconnects with exponential backoff; PV polling continues in the background
- PV health monitoring re-subscribes or rebuilds the `Context` if many PVs disconnect
- File log retrieval tolerates missing files and large logs (reads last 500KB)
- FITS preview gracefully degrades when no files are present

### Extending the UI
- Add PVs/events:
  - Update `PVSubscriptionManager.setup_core_subscriptions` to subscribe
  - Render in UI by handling new keys in `processUpdates` and updating the DOM
- New actions:
  - Add Flask route and wire from Monitoring Actions select + handler
  - For host commands, add SSH invocation in `run_ssh_command`
  - For PV writes, use `caput` with `wait=True` where appropriate
- Config keys:
  - Add to `Config Editor` by placing the keys in `conf/gnirsdc/config.ini`
  - Ensure the server reads keys from the active `config_mode` (DEFAULT/DEBUG)

### Testing and diagnostics
- Run locally in devcontainer (`dc-devel.sh`) or directly:
  ```bash
  python3 src/system_manager_server.py --debug --port 8080
  ```
- Use the TCS simulator: `python3 test/tcs_simulator.py`
- Verify PV streams at `/sse`, REST at `/get_all_pvs`, and actions via the Monitoring page
- Check server logs (stdout) for SSE backoff, subscription rebuilds, and route errors

### Known caveats
- The server sets `os.chdir` to `src/` so relative paths (templates/static/conf) resolve; be mindful when changing file locations
- Changing active mode (Normal/Debug) restarts PV subscriptions to the new top name; ensure related UI state resets are handled
- Long-running file log reads are throttled but polled frequently; adjust polling interval if needed for performance

For operator procedures and day-to-day usage, see `CONOPS.md` (the System Manager section). This document focuses on the underlying server behavior for maintenance.
