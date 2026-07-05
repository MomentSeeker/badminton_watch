#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${DEVICE_ID:-00008310-0008A59034E0E01E}"
BUNDLE_ID="${BUNDLE_ID:-com.lichaochen.kineticvelocity.watch}"
OUT_DIR="${1:-./ExportedSwingWindows}"

mkdir -p "$OUT_DIR"

xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "Documents/KineticVelocity/swing_windows.jsonl" \
  --destination "$OUT_DIR/swing_windows.jsonl" \
  --timeout 60

echo "Exported $OUT_DIR/swing_windows.jsonl"

if xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "Documents/KineticVelocity/diagnostics.log" \
  --destination "$OUT_DIR/diagnostics.log" \
  --timeout 60; then
  echo "Exported $OUT_DIR/diagnostics.log"
else
  echo "No diagnostics.log found yet"
fi
