#!/usr/bin/env sh
set -eu

CAN_IFACE="${CAN_IFACE:-can0}"
PYTHON_BIN="${PYTHON_BIN:-$HOME/klippy-env/bin/python}"
KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
OUT_CFG="${OUT_CFG:-$HOME/printer_data/config/canuid.cfg}"

if [ ! -x "$PYTHON_BIN" ]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  else
    echo "ERROR: Python interpreter not found."
    exit 1
  fi
fi

QUERY_SCRIPT="$KLIPPER_DIR/scripts/canbus_query.py"
if [ ! -f "$QUERY_SCRIPT" ]; then
  echo "ERROR: Missing canbus query script: $QUERY_SCRIPT"
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

"$PYTHON_BIN" "$QUERY_SCRIPT" "$CAN_IFACE" \
  | sed 's/^.*Found canbus_uuid=/canbus_uuid:/g' \
  | sed 's/,.*$//g' \
  | sed '/^Total.*$/d' \
  | sed '/^$/d' > "$tmp_file"

if ! grep -q '^canbus_uuid:' "$tmp_file"; then
  echo "ERROR: No CAN UUIDs detected on $CAN_IFACE"
  exit 1
fi

{
  echo "[mcu]"
  sed -n '1p' "$tmp_file"
  echo "[mcu EECAN]"
  sed -n '2p' "$tmp_file"
} > "$OUT_CFG"

cat "$OUT_CFG"
sync
