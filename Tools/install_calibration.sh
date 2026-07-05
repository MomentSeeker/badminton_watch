#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${DEVICE_ID:-00008310-0008A59034E0E01E}"
BUNDLE_ID="${BUNDLE_ID:-com.lichaochen.kineticvelocity.watch}"
CALIBRATION_JSON="${1:-./CalibrationData/swing_calibration.json}"

if [[ ! -f "$CALIBRATION_JSON" ]]; then
  echo "Missing calibration file: $CALIBRATION_JSON" >&2
  exit 1
fi

xcrun devicectl device copy to \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "$CALIBRATION_JSON" \
  --destination "Documents/KineticVelocity/swing_calibration.json" \
  --timeout 60

echo "Installed $CALIBRATION_JSON"
