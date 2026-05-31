#!/usr/bin/env bash

# File: scripts/mcu/request_bootloader_and_query.sh
# Purpose: Request Katapult bootloader mode for UUIDs and query CAN visibility.
#
set -euo pipefail

ENV_FILE=""
KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
KATAPULT_DIR="${KATAPULT_DIR:-$HOME/katapult}"
CAN_IFACE="${CAN_IFACE:-can0}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

declare -a UUIDS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/mcu/request_bootloader_and_query.sh [options]

Request Katapult/CanBoot mode for one or more CAN UUIDs and verify with -q.
This script does not flash firmware.

UUID input (choose one path):
  --uuid <uuid>              Add a UUID to process (repeatable)
  --mainboard-uuid <uuid>    Convenience alias for --uuid
  --toolhead-uuid <uuid>     Convenience alias for --uuid
  --env-file <path>          Load MAINBOARD_UUID / TOOLHEAD_UUID from env file

Options:
  --klipper-dir <path>       Path to Klipper checkout (default: ~/klipper)
  --katapult-dir <path>      Path to Katapult checkout (default: ~/katapult)
  --can-iface <iface>        CAN interface (default: can0)
  --python-bin <path>        Python binary for flashtool.py (default: python3)
  -h, --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uuid|--mainboard-uuid|--toolhead-uuid)
      UUIDS+=("$2")
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --klipper-dir)
      KLIPPER_DIR="$2"
      shift 2
      ;;
    --katapult-dir)
      KATAPULT_DIR="$2"
      shift 2
      ;;
    --can-iface)
      CAN_IFACE="$2"
      shift 2
      ;;
    --python-bin)
      PYTHON_BIN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$ENV_FILE" ]]; then
  [[ -f "$ENV_FILE" ]] || {
    echo "Missing env file: $ENV_FILE" >&2
    exit 1
  }

  # shellcheck disable=SC1090
  source "$ENV_FILE"

  if [[ -n "${MAINBOARD_UUID:-}" ]]; then
    UUIDS+=("${MAINBOARD_UUID}")
  fi
  if [[ -n "${TOOLHEAD_UUID:-}" ]]; then
    UUIDS+=("${TOOLHEAD_UUID}")
  fi
fi

[[ "${#UUIDS[@]}" -gt 0 ]] || {
  echo "No UUIDs provided. Use --uuid ... or --env-file ..." >&2
  exit 1
}

# De-duplicate UUID list while preserving order.
declare -A SEEN=()
declare -a UNIQUE_UUIDS=()
for uuid in "${UUIDS[@]}"; do
  if [[ -z "${SEEN[$uuid]:-}" ]]; then
    UNIQUE_UUIDS+=("$uuid")
    SEEN["$uuid"]=1
  fi
done

FLASHTOOL="$KATAPULT_DIR/scripts/flashtool.py"
if [[ ! -f "$FLASHTOOL" ]]; then
  # Backward-compatible fallback for layouts where Katapult only exists inside
  # the Klipper tree.
  FLASHTOOL="$KLIPPER_DIR/lib/katapult/flashtool.py"
fi
[[ -f "$FLASHTOOL" ]] || {
  echo "Missing Katapult flashtool. Checked:" >&2
  echo "  $KATAPULT_DIR/scripts/flashtool.py" >&2
  echo "  $KLIPPER_DIR/lib/katapult/flashtool.py" >&2
  exit 1
}

run_flashtool() {
  "$PYTHON_BIN" "$FLASHTOOL" "$@"
}

echo "Using flashtool: $FLASHTOOL"
echo "Using python:    $PYTHON_BIN"
echo "Using CAN iface: $CAN_IFACE"

for uuid in "${UNIQUE_UUIDS[@]}"; do
  echo ""
  echo "Requesting bootloader for UUID: $uuid"
  run_flashtool -i "$CAN_IFACE" -u "$uuid" -r
done

echo ""
echo "Querying bootloader-visible UUIDs"
QUERY_OUTPUT="$(run_flashtool -i "$CAN_IFACE" -q || true)"
echo "$QUERY_OUTPUT"

missing=0
for uuid in "${UNIQUE_UUIDS[@]}"; do
  if grep -Fq "$uuid" <<< "$QUERY_OUTPUT"; then
    echo "[ok] UUID is in bootloader query: $uuid"
  else
    echo "[warn] UUID not found in bootloader query: $uuid" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "One or more UUIDs did not appear in -q output." >&2
  echo "If Klipper was not running on that MCU, -r may not be able to hand off to Katapult." >&2
  exit 2
fi

echo "All requested UUIDs are now visible in Katapult query mode."
