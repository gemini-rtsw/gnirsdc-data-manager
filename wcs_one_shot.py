#!/usr/bin/env python3
"""
One-shot WCS builder that reuses the repo's TCS and WCS helpers.

- Grabs the current TCS values with a single round of pyepics cagets.
- Calls wcs_utils.process_wcs_data to build the WCS using the existing config and WCS tables.
- Writes the key WCS keywords to wcs_output.txt in the repo root.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any, Dict

import numpy as np
from epics import caget

# Make sure imports resolve the same way as in the main app
ROOT = Path(__file__).resolve().parent
SRC_DIR = ROOT / "src"
os.chdir(SRC_DIR)
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from tcs_monitor import TCSMonitor  # noqa: E402
from wcs_utils import process_wcs_data  # noqa: E402
from gnirsutil import config, config_mode  # noqa: E402  # ensures config is loaded


# Map the PV short name (final field) to the context key expected by wcs_utils
PV_MAPPING = {
    "currentRA": "track_ra",
    "currentDec": "track_dec",
    "sourceATrackFrame": "track_frame",
    "sourceAEpoch": "track_equinox",
    "sourceADiffRA.VAL": "ra_offset",
    "sourceADiffDec.VAL": "dec_offset",
    "sourceAPMRA.VAL": "pm_ra",
    "sourceAPMDec.VAL": "pm_dec",
    "instrAA.VAL": "inst_iaa",
    "instrPA.VAL": "inst_pa",
    "cameraPosition": "camera",
    "nirs": "port",
    "aoName": "ao",
}


def decode_value(value: Any) -> Any:
    """Convert pyepics return values into plain Python types."""
    if isinstance(value, (list, np.ndarray)):
        return "".join(chr(int(i)) for i in value if int(i) != 0)
    return value


def fetch_tcs_context() -> Dict[str, Any]:
    """Grab one snapshot of the TCS PVs and shape them for process_wcs_data."""
    monitor = TCSMonitor()
    snapshot: Dict[str, Any] = {}

    for pv in monitor.tcs_pvs:
        val = caget(pv, timeout=1.0, use_monitor=False)
        if val is None:
            raise RuntimeError(f"PV {pv} returned no value")
        short_name = pv.split(":")[-1]
        snapshot[short_name] = decode_value(val)

    tcs_context: Dict[str, Any] = {}
    for pv_short, ctx_key in PV_MAPPING.items():
        if pv_short not in snapshot:
            raise RuntimeError(f"PV {pv_short} missing from snapshot; cannot build WCS context")
        tcs_context[ctx_key] = snapshot[pv_short]

    # Fill in types expected by wcs_utils
    tcs_context["time"] = float(monitor.get_ntp_time())
    tcs_context["port"] = int(tcs_context["port"])
    tcs_context["camera"] = str(tcs_context["camera"]).strip()
    tcs_context["ao"] = str(tcs_context["ao"]).strip()
    tcs_context["inst_pa"] = float(tcs_context.get("inst_pa", 0.0))
    tcs_context["inst_iaa"] = float(tcs_context.get("inst_iaa", 0.0))
    tcs_context["ra_offset"] = float(tcs_context.get("ra_offset", 0.0))
    tcs_context["dec_offset"] = float(tcs_context.get("dec_offset", 0.0))
    tcs_context["pm_ra"] = float(tcs_context.get("pm_ra", 0.0))
    tcs_context["pm_dec"] = float(tcs_context.get("pm_dec", 0.0))

    return tcs_context


def format_wcs(wcs) -> str:
    """Return a small text representation of the WCS for logging/inspection."""
    lines = [
        f"CTYPE1 = {wcs.wcs.ctype[0]}",
        f"CTYPE2 = {wcs.wcs.ctype[1]}",
        f"CRPIX1 = {wcs.wcs.crpix[0]}",
        f"CRPIX2 = {wcs.wcs.crpix[1]}",
        f"CRVAL1 = {wcs.wcs.crval[0]}",
        f"CRVAL2 = {wcs.wcs.crval[1]}",
        f"CD1_1  = {wcs.wcs.cd[0, 0]}",
        f"CD1_2  = {wcs.wcs.cd[0, 1]}",
        f"CD2_1  = {wcs.wcs.cd[1, 0]}",
        f"CD2_2  = {wcs.wcs.cd[1, 1]}",
        f"EQUINOX= {getattr(wcs.wcs, 'equinox', '')}",
        f"RADESYS= {getattr(wcs.wcs, 'radesys', '')}",
    ]
    return "\n".join(lines) + "\n"


def main():
    tcs_context = fetch_tcs_context()

    wcs = process_wcs_data(
        int(tcs_context["port"]),
        str(tcs_context["camera"]),
        str(tcs_context["ao"]),
        tcs_context,
    )

    output_path = ROOT / "wcs_output.txt"
    output_path.write_text(format_wcs(wcs))
    print(f"WCS written to {output_path}")


if __name__ == "__main__":
    main()
