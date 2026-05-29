#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
KATAPULT_DIR="${KATAPULT_DIR:-$HOME/katapult}"
CAN_IFACE="${CAN_IFACE:-can0}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/out/mcu}"

MAINBOARD_BIN="${MAINBOARD_BIN:-$OUTPUT_DIR/klipper_mainboard.bin}"
TOOLHEAD_BIN="${TOOLHEAD_BIN:-$OUTPUT_DIR/klipper_toolhead.bin}"

MAINBOARD_UUID="${MAINBOARD_UUID:-}"
TOOLHEAD_UUID="${TOOLHEAD_UUID:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/mcu/flash_klipper_mcus_katapult.sh [options]

Required:
  --mainboard-uuid <uuid>
  --toolhead-uuid <uuid>

Options:
  --klipper-dir <path>      Path to mainline Klipper checkout (default: ~/klipper)
  --katapult-dir <path>     Path to Katapult checkout (default: ~/katapult)
  --can-iface <iface>       CAN interface (default: can0)
  --output-dir <path>       Directory holding compiled binaries
  --mainboard-bin <path>    Mainboard klipper binary
  --toolhead-bin <path>     Toolhead klipper binary
  -h, --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mainboard-uuid)
      MAINBOARD_UUID="$2"
      shift 2
      ;;
    --toolhead-uuid)
      TOOLHEAD_UUID="$2"
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
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --mainboard-bin)
      MAINBOARD_BIN="$2"
      shift 2
      ;;
    --toolhead-bin)
      TOOLHEAD_BIN="$2"
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

[[ -n "$MAINBOARD_UUID" ]] || { echo "Missing --mainboard-uuid" >&2; exit 1; }
[[ -n "$TOOLHEAD_UUID" ]] || { echo "Missing --toolhead-uuid" >&2; exit 1; }

[[ -f "$MAINBOARD_BIN" ]] || { echo "Missing mainboard binary: $MAINBOARD_BIN" >&2; exit 1; }
[[ -f "$TOOLHEAD_BIN" ]] || { echo "Missing toolhead binary: $TOOLHEAD_BIN" >&2; exit 1; }

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

flash_one() {
  local role="$1"
  local uuid="$2"
  local bin="$3"

  echo "[$role] Requesting bootloader via CAN UUID $uuid"
  python3 "$FLASHTOOL" -i "$CAN_IFACE" -u "$uuid" -r

  echo "[$role] Flashing $bin"
  python3 "$FLASHTOOL" -i "$CAN_IFACE" -u "$uuid" -f "$bin"
}

flash_one "mainboard" "$MAINBOARD_UUID" "$MAINBOARD_BIN"
flash_one "toolhead" "$TOOLHEAD_UUID" "$TOOLHEAD_BIN"

echo "Flash complete for both MCUs."
