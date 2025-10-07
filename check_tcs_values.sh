#!/bin/bash

# Script to check TCS values that nirsg:dc:astCtx needs
# Usage: ./check_tcs_values.sh [tcs_prefix]
# Default prefix is "tcs" but can be overridden

TOP=${1:-tcs}

echo "Checking TCS values with prefix: $TOP"
echo "================================================"

echo "1. Checking astCtx array (INPA):"
caget ${TOP}:ak:astCtx.VALA

echo ""
echo "2. Checking sourceATrackFrame (INPB):"
caget ${TOP}:sad:sourceATrackFrame

echo ""
echo "3. Checking sourceATrackEq (INPC):"
caget ${TOP}:sad:sourceATrackEq

echo ""
echo "4. Checking sourceAWavelength (INPD):"
caget ${TOP}:sad:sourceAWavelength

echo ""
echo "5. Checking sourceAEpoch (what code expects for INPC):"
caget ${TOP}:sad:sourceAEpoch

echo ""
echo "Additional TCS diagnostics:"
echo "================================================"

echo "TCS heartbeat:"
caget ${TOP}:heartbeat 2>/dev/null || echo "No heartbeat PV found"

echo ""
echo "Current RA/Dec:"
caget ${TOP}:sad:currentRA 2>/dev/null || echo "No currentRA PV found"
caget ${TOP}:sad:currentDec 2>/dev/null || echo "No currentDec PV found"

echo ""
echo "Instrument PA:"
caget ${TOP}:sad:instrPA 2>/dev/null || echo "No instrPA PV found"

echo ""
echo "Parallactic angle:"
caget ${TOP}:sad:parAngle 2>/dev/null || echo "No parAngle PV found"

echo ""
echo "WCS-specific TCS diagnostics:"
echo "================================================"

echo "All PVs needed for WCS calculation:"
echo ""

echo "1. Track RA (required):"
caget ${TOP}:sad:currentRA 2>/dev/null || echo "ERROR: currentRA PV not found or not connected"

echo ""
echo "2. Track DEC (required):"
caget ${TOP}:sad:currentDec 2>/dev/null || echo "ERROR: currentDec PV not found or not connected"

echo ""
echo "3. Track Frame (required):"
caget ${TOP}:sad:sourceATrackFrame 2>/dev/null || echo "ERROR: sourceATrackFrame PV not found or not connected"

echo ""
echo "4. Track Equinox (required):"
caget ${TOP}:sad:sourceAEpoch 2>/dev/null || echo "ERROR: sourceAEpoch PV not found or not connected"

echo ""
echo "5. RA Offset (optional, defaults to 0):"
caget ${TOP}:sad:sourceADiffRA.VAL 2>/dev/null || echo "WARNING: sourceADiffRA.VAL PV not found (will default to 0)"

echo ""
echo "6. DEC Offset (optional, defaults to 0):"
caget ${TOP}:sad:sourceADiffDec.VAL 2>/dev/null || echo "WARNING: sourceADiffDec.VAL PV not found (will default to 0)"

echo ""
echo "7. Proper Motion RA (optional, defaults to 0):"
caget ${TOP}:sad:sourceAPMRA.VAL 2>/dev/null || echo "WARNING: sourceAPMRA.VAL PV not found (will default to 0)"

echo ""
echo "8. Proper Motion DEC (optional, defaults to 0):"
caget ${TOP}:sad:sourceAPMDec.VAL 2>/dev/null || echo "WARNING: sourceAPMDec.VAL PV not found (will default to 0)"

echo ""
echo "9. Instrument AA (required for rotation):"
caget ${TOP}:sad:instrAA.VAL 2>/dev/null || echo "ERROR: instrAA.VAL PV not found or not connected"

echo ""
echo "10. Instrument PA (required for rotation):"
caget ${TOP}:sad:instrPA.VAL 2>/dev/null || echo "ERROR: instrPA.VAL PV not found or not connected"

echo ""
echo "11. Camera Position (required for WCS file selection):"
caget tgnirs:sad:cc:cameraPosition 2>/dev/null || echo "ERROR: cameraPosition PV not found or not connected"

echo ""
echo "12. Port (required for WCS file selection):"
caget tag:port:nirs 2>/dev/null || echo "ERROR: port:nirs PV not found or not connected"

echo ""
echo "13. AO Name (required for WCS file selection):"
caget tag:aoName 2>/dev/null || echo "ERROR: aoName PV not found or not connected"

echo ""
echo "14. Time (MJD, required):"
caget ${TOP}:sad:djmls 2>/dev/null || echo "ERROR: djmls (MJD time) PV not found or not connected"

echo ""
echo "Data format analysis:"
echo "================================================"

echo "Checking RA format (should be HH:MM:SS.SS):"
RA_VAL=$(caget -t ${TOP}:sad:currentRA 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "RA value: '$RA_VAL'"
    if [[ $RA_VAL =~ ^[0-9]{1,2}:[0-9]{2}:[0-9]{2}\.[0-9]+$ ]]; then
        echo "✓ RA format looks correct (sexagesimal)"
    else
        echo "✗ RA format may be incorrect - expected HH:MM:SS.SS format"
    fi
else
    echo "✗ Could not retrieve RA value"
fi

echo ""
echo "Checking DEC format (should be ±DD:MM:SS.SS):"
DEC_VAL=$(caget -t ${TOP}:sad:currentDec 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "DEC value: '$DEC_VAL'"
    if [[ $DEC_VAL =~ ^[+-][0-9]{1,2}:[0-9]{2}:[0-9]{2}\.[0-9]+$ ]]; then
        echo "✓ DEC format looks correct (sexagesimal)"
    else
        echo "✗ DEC format may be incorrect - expected ±DD:MM:SS.SS format"
    fi
else
    echo "✗ Could not retrieve DEC value"
fi

echo ""
echo "Checking Equinox format (should be J2000.0 or similar):"
EQUINOX_VAL=$(caget -t ${TOP}:sad:sourceAEpoch 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Equinox value: '$EQUINOX_VAL'"
    if [[ $EQUINOX_VAL =~ ^J?[0-9]{4}(\.[0-9]+)?$ ]]; then
        echo "✓ Equinox format looks correct"
    else
        echo "✗ Equinox format may be incorrect - expected J2000.0 format"
    fi
else
    echo "✗ Could not retrieve Equinox value"
fi

echo ""
echo "Checking Camera format (should contain 'short' or 'long'):"
CAMERA_VAL=$(caget -t tgnirs:sad:cc:cameraPosition 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Camera value: '$CAMERA_VAL'"
    if [[ $CAMERA_VAL =~ (short|long|Short|Long) ]]; then
        echo "✓ Camera format looks correct (contains short/long)"
    else
        echo "✗ Camera format may be incorrect - should contain 'short' or 'long'"
    fi
else
    echo "✗ Could not retrieve Camera value"
fi

echo ""
echo "Checking Port format (should be integer 0, 1, 3, or 5):"
PORT_VAL=$(caget -t tag:port:nirs 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Port value: '$PORT_VAL'"
    if [[ $PORT_VAL =~ ^[0135]$ ]]; then
        echo "✓ Port format looks correct (0, 1, 3, or 5)"
    else
        echo "✗ Port format may be incorrect - should be 0, 1, 3, or 5"
    fi
else
    echo "✗ Could not retrieve Port value"
fi

echo ""
echo "Summary of critical issues:"
echo "================================================"

# Check for critical missing values
CRITICAL_MISSING=0

if ! caget ${TOP}:sad:currentRA &>/dev/null; then
    echo "✗ CRITICAL: currentRA is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if ! caget ${TOP}:sad:currentDec &>/dev/null; then
    echo "✗ CRITICAL: currentDec is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if ! caget ${TOP}:sad:sourceATrackFrame &>/dev/null; then
    echo "✗ CRITICAL: sourceATrackFrame is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if ! caget ${TOP}:sad:sourceAEpoch &>/dev/null; then
    echo "✗ CRITICAL: sourceAEpoch is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if ! caget ${TOP}:sad:instrAA.VAL &>/dev/null; then
    echo "✗ CRITICAL: instrAA.VAL is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if ! caget ${TOP}:sad:instrPA.VAL &>/dev/null; then
    echo "✗ CRITICAL: instrPA.VAL is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if ! caget tgnirs:sad:cc:cameraPosition &>/dev/null; then
    echo "✗ CRITICAL: cameraPosition is missing - WCS file selection will fail"
    CRITICAL_MISSING=1
fi

if ! caget tag:port:nirs &>/dev/null; then
    echo "✗ CRITICAL: port:nirs is missing - WCS file selection will fail"
    CRITICAL_MISSING=1
fi

if ! caget tag:aoName &>/dev/null; then
    echo "✗ CRITICAL: aoName is missing - WCS file selection will fail"
    CRITICAL_MISSING=1
fi

if ! caget ${TOP}:sad:djmls &>/dev/null; then
    echo "✗ CRITICAL: djmls (MJD time) is missing - WCS calculation will fail"
    CRITICAL_MISSING=1
fi

if [ $CRITICAL_MISSING -eq 0 ]; then
    echo "✓ All critical PVs are available"
    echo ""
    echo "If WCS is still failing, check the data format issues above"
    echo "or look for errors in the wcs_utils.py calculation logic"
else
    echo ""
    echo "WCS calculation will fail due to missing critical PVs above"
fi

echo ""
echo "Done checking TCS values."
