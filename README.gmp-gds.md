## GMP/GDS Container Setup – Engineering Guide

This document provides a complete guide for engineers implementing or maintaining the GMP (Gemini Master Process) and GDS (Gemini Data System) container for the GNIRS Detector Controller. It covers architecture, dependencies, configuration, build process, and runtime behavior.

### Overview

The GMP/GDS container provides the Gemini Observatory's standard infrastructure for:
- **GIAPI Communication**: Message broker (ActiveMQ) for instrument-to-observatory communication
- **Keyword Collection**: Gathering FITS header keywords from various subsystems (SEQEXEC, TCS, EPICS)
- **FITS Post-processing**: Setting file ownership, permissions, and archiving processed files

The GMP server runs as an OSGi (Felix) application written in Java/Scala, receiving observation lifecycle events from the instrument IOC and injecting collected keywords into FITS files.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GMP Container                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  gmp-server (Java/OSGi)                 │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │    │
│  │  │  ActiveMQ    │  │     GDS      │  │   GIAPI      │   │    │
│  │  │   Broker     │  │  Keywords    │  │  Services    │   │    │
│  │  │  (tcp:61616) │  │              │  │              │   │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │    │
│  │                                                         │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │              Web Console (port 8888)             │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Volumes:                                                       │
│    /readout_data  - Raw FITS from DC, logs                      │
│    /staging/perm  - Processed FITS output                       │
└─────────────────────────────────────────────────────────────────┘
```

### Dependencies

#### GMP Server Distribution

The GMP server distribution (`gmp-server-0.2.6-SNAPSHOT`) is published by the
[gnirsdc-giapi-gmp](https://github.com/gemini-rtsw/gnirsdc-giapi-gmp) repo: the
tarball is a GitHub Release asset there, checksummed in its `RELEASES` file, and
its image carries the unpacked tree. It contains:
- OSGi Felix framework and bundles
- GDS (Gemini Data System) modules
- GIAPI services
- ActiveMQ JMS broker
- Web console

**Source**: The GMP server is built from the Gemini ASPEN repository. Contact the Gemini software team for updated distributions; a new one becomes a new release in gnirsdc-giapi-gmp.

#### Image

GMP runs from the same image as the DC (this repo's `Dockerfile`, Rocky Linux 9),
which adds Java 8, `procps-ng`, `sudo` and the `gemdhs` user for it:

```dockerfile
RUN dnf -y install java-1.8.0-openjdk-headless procps-ng sudo
RUN useradd -m -u 1000 gemdhs
COPY --from=ghcr.io/gemini-rtsw/gnirsdc-giapi-gmp:1.0.0-gitf07d23a /gmp-server-0.2.6-SNAPSHOT /usr/local/share/gmp-server
COPY conf/gmp/ /usr/local/share/gmp-server/conf/
ENV JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk
```

### File Structure

```
gnirsdc-data-manager/
├── Dockerfile                  # Image for the DC, the System Manager and GMP
├── entrypoint-gmp.sh           # GMP container entrypoint
├── conf/
│   └── gmp/
│       ├── config.properties           # Main GMP configuration
│       ├── gds-keywords.conf           # FITS keyword definitions
│       ├── gds-keywords-highcount.conf # Alt config for testing
│       ├── epics-channels.xml          # Authorized EPICS channels
│       ├── giapi-apply-config.xml      # GIAPI apply configuration
│       ├── giapi-epics-status-mapping.xml
│       ├── simulated-epics-channels.xml
│       ├── status-simulator.xml
│       ├── status-translator.xml
│       ├── tcsCtx.data
│       ├── webui-users.xml             # Web console authentication
│       └── services/                   # OSGi service configs
│           ├── edu.gemini.aspen.gds.GdsConfiguration-default.cfg
│           ├── edu.gemini.gmp.top.Top-default.cfg
│           ├── edu.gemini.jms.activemq.broker.ActiveMQBrokerComponent-default.cfg
│           └── ... (25+ service configuration files)
```

### Entrypoint Script

`dc-start.sh` starts the `gmp` container from the DC image with
`--entrypoint /gnirsdc/entrypoint-gmp.sh`. The GMP server is already unpacked
at `/usr/local/share/gmp-server`, with `conf/gmp` copied over its `conf/` when
the image was built, so the entrypoint only starts it:

```bash
#!/bin/bash
cd /usr/local/share/gmp-server
./bin/gmp-server-ctl.sh start

# Keep container running
while true; do sleep 1; done
```

### Key Configuration Files

#### `config.properties`
Main GMP/GDS configuration:

| Property | Value | Description |
|----------|-------|-------------|
| `gmp.instance` | `igrins2` | Instance identifier |
| `gmp.version` | `0.2.6-SNAPSHOT` | GMP version |
| `logs.dir` | `/readout_data/logs` | Log output directory |
| `org.osgi.service.http.port` | `8888` | Web console port |
| `osgi.shell.telnet.port` | `15001` | Telnet shell port |
| `felix.fileinstall.dir` | `../../conf/services` | OSGi service configs |
| `conf.base` | `../../conf` | Configuration base path |

#### `services/edu.gemini.gmp.top.Top-default.cfg`
EPICS prefix configuration:

```properties
epicsTop=nirs
giapiTop=nirs
```

This sets the EPICS channel prefix for all GMP EPICS interactions. Change this to match your instrument's EPICS top name.

#### `services/edu.gemini.aspen.gds.GdsConfiguration-default.cfg`
GDS behavior configuration:

```properties
keywordsConfiguration=../../conf/gds-keywords.conf
observation.cleanupRate=1 hour
observation.lifespan=12 hours
seqexec.server.port=8088
seqexec.server.host=0.0.0.0

# FITS post-processing
fits.setOwner=true
fits.setOwner.owner=gemdhs
fits.setOwner.useSudo=true
fits.setPermissions=true
fits.setPermissions.permissions=0644
fits.setPermissions.useSudo=true
fits.deleteOriginal=true
```

#### `services/edu.gemini.jms.activemq.broker.ActiveMQBrokerComponent-default.cfg`
ActiveMQ broker settings:

```properties
brokerName=gmp
brokerUrl=tcp://0.0.0.0:61616
persistent=false
deleteMsgOnStartup=true
maxStorageMB=500
memoryPercentage=0.25
maxMessagesLimit=50
```

#### `gds-keywords.conf`
Defines FITS header keywords to collect. Format:

```
#Instrument  Event         Keyword   Ext  Type    Mandatory  Default  Source     Channel  Index  Format  Comment
GNIRS        OBS_PREP      OBJECT    0    STRING  T          Sky      SEQEXEC    OBJECT   0      ""      "Object Name"
GNIRS        OBS_PREP      OBSTYPE   0    STRING  T          NONE     SEQEXEC    OBSTYPE  0      ""      "Observation type"
GNIRS        OBS_START_ACQ AZIMUTH   0    DOUBLE  T          NONE     SEQEXEC    AZIMUTH  0      ""      "Telescope Azimuth"
...
```

Columns:
- **Instrument**: Instrument name (GNIRS)
- **Event**: When to collect (OBS_PREP, OBS_START_ACQ, OBS_END_ACQ, EXT_END_OBS)
- **Keyword**: FITS header keyword name
- **Ext**: FITS extension (0 = primary)
- **Type**: Data type (STRING, DOUBLE, INT)
- **Mandatory**: T/F
- **Default**: Default value if source unavailable
- **Source**: Data source (SEQEXEC, EPICS, etc.)
- **Channel**: Source channel/variable name
- **Index**: Array index if applicable
- **Format**: Output format
- **Comment**: FITS header comment

#### `epics-channels.xml`
Authorized EPICS channels for GMP to monitor:

```xml
<channels>
    <channel>ag:port:nirs</channel>
    <channel>tcs:sad:chopState</channel>
    <channel>tcs:sad:currentAirPressure</channel>
    <channel>tcs:sad:currentRA</channel>
    <channel>tcs:sad:currentDec</channel>
    <!-- ... more channels ... -->
</channels>
```

### Build Process

The image is built by gemini-rtsw-ci with the rest of this repo (see the root
README, "Building, Releasing and Deploying"); there is no separate GMP image.

### Running the Container

#### On the DC host

`dc-start.sh` (run by the System Manager) starts `gmp` alongside `gnirsdc`, from
the image the installed `gnirsdc-data-manager` RPM pins.

#### Running with Docker (development)

```bash
docker run -d --network=host --name gmp \
  -v /readout_data:/readout_data \
  -v /staging/perm:/staging/perm \
  --entrypoint /gnirsdc/entrypoint-gmp.sh \
  ghcr.io/gemini-rtsw/gnirsdc-data-manager:latest
```

On macOS, `dc-mac-test.sh` starts GMP with published ports instead.

#### Required Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/readout_data` | `/readout_data` | Raw FITS input, logs |
| `/staging/perm` | `/staging/perm` | Processed FITS output |

#### Network Requirements

The container must use `--network=host` to:
- Receive GIAPI events from the DC IOC
- Connect to EPICS channels
- Accept connections on ActiveMQ (61616), HTTP (8888), and Telnet (15001) ports

### Exposed Ports

| Port | Service | Description |
|------|---------|-------------|
| 61616 | ActiveMQ | JMS message broker |
| 8888 | HTTP | Web console |
| 8088 | HTTP | SEQEXEC event listener |
| 15001 | Telnet | OSGi shell |
| 2098 | JMX RMI | JMX RMI server |
| 2099 | JMX | JMX connector |

### GDS Keyword Collection Flow

1. **IOC posts observation events** via GIAPI (e.g., `OBS_PREP`, `OBS_START_ACQ`)
2. **GDS receives events** and looks up keywords for that event type in `gds-keywords.conf`
3. **GDS collects keyword values** from configured sources (SEQEXEC, EPICS)
4. **On `OBS_END_DSET_WRITE`**, GDS:
   - Reads the raw FITS file from `/readout_data`
   - Injects collected keywords into FITS headers
   - Sets file ownership to `gemdhs` (via sudo)
   - Sets permissions to `0644`
   - Writes processed file to `/staging/perm`
   - Optionally deletes original (`fits.deleteOriginal=true`)

### Web Console Access

The GMP web console is available at:

```
http://<host>:8888
```

Default credentials are configured in `conf/gmp/webui-users.xml`.

Features:
- View OSGi bundle status
- Monitor GDS observations
- View collected keywords
- Check service health

### Troubleshooting

#### Check if GMP is Running

```bash
docker logs gmp
```

Look for:
```
GMP Server started
```

#### Verify ActiveMQ Broker

```bash
# Test TCP connection
nc -zv localhost 61616
```

#### Check GDS Configuration

```bash
docker exec gmp cat /usr/local/share/gmp-server/conf/gds-keywords.conf
```

#### View OSGi Bundle Status

Connect to the telnet shell:

```bash
telnet localhost 15001
```

Commands:
- `lb` - List bundles
- `scr:list` - List components
- `log:display` - View logs

#### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| FITS files not processed | GDS not receiving events | Check GIAPI connectivity |
| Keywords missing | Source unavailable | Verify EPICS/SEQEXEC channels |
| Permission denied on FITS | sudo not working | Verify `gemdhs` user exists |
| Container exits immediately | Java not starting | Check `JAVA_HOME` and Java installation |

### Implementing for Another Instrument

To adapt this setup for a different instrument:

1. **Update EPICS top name** in `services/edu.gemini.gmp.top.Top-default.cfg`:
   ```properties
   epicsTop=<your_instrument>
   giapiTop=<your_instrument>
   ```

2. **Modify keyword configuration** in `gds-keywords.conf`:
   - Change instrument name from `GNIRS` to your instrument
   - Add/remove keywords as needed for your FITS headers
   - Update source channels to match your EPICS PVs

3. **Update authorized EPICS channels** in `epics-channels.xml`:
   - Add channels your instrument needs to read

4. **Adjust GDS settings** in `services/edu.gemini.aspen.gds.GdsConfiguration-default.cfg`:
   - Update file ownership if different user needed
   - Adjust observation lifespan if needed

5. **Update volume mounts** if different paths are used for FITS storage

### Related Documentation

- `README.gnirsgiapi.md` - GIAPI integration details
- `README.md` - Main project documentation
- `README.system-manager.md` - System Manager web interface

### Version History

| GMP Version | Notes |
|-------------|-------|
| 0.2.6-SNAPSHOT | Current version, configured for GNIRS |

### Contact

For questions about the GMP/GDS infrastructure, contact the Gemini software team or refer to the ASPEN project documentation.

