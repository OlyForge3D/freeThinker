#!/usr/bin/env bash

# File: scripts/mcu/update_both_mcus.sh
# Purpose: End-to-end MCU build and flash workflow with UUID/env handling.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV_FILE="${ENV_FILE:-$REPO_ROOT/config/support/mcu/mcu-update.env}"
UPDATE_CANUID_CFG=0
CANUID_CFG="${CANUID_CFG:-$HOME/printer_data/config/canuid.cfg}"

extract_uuid_from_canuid() {
  local cfg="$1"
  local section="$2"
  awk -F: -v section="$section" '
    $0 == "[" section "]" { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && /^canbus_uuid:/ {
      gsub(/[[:space:]]/, "", $2)
      print tolower($2)
      exit
    }
  ' "$cfg"
}

is_valid_uuid() {
  [[ "$1" =~ ^[0-9a-f]{12}$ ]]
}

usage() {
  cat <<'EOF'
Usage: ./scripts/mcu/update_both_mcus.sh [options]

Options:
  --env-file <path>         Path to env file (default: config/support/mcu/mcu-update.env)
  --canuid-cfg <path>       Read UUID fallback from this canuid.cfg path
  --update-canuid-cfg       Write local config/local/canuid.cfg with provided UUIDs
  -h, --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --canuid-cfg)
      CANUID_CFG="$2"
      shift 2
      ;;
    --update-canuid-cfg)
      UPDATE_CANUID_CFG=1
      shift
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

[[ -f "$ENV_FILE" ]] || {
  echo "Missing env file: $ENV_FILE" >&2
  echo "Copy config/support/mcu/mcu-update.env.example to config/support/mcu/mcu-update.env and edit values." >&2
  exit 1
}

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${KLIPPER_DIR:?KLIPPER_DIR is required in env file}"

if [[ -z "${MAINBOARD_UUID:-}" || -z "${TOOLHEAD_UUID:-}" ]]; then
  if [[ -f "$CANUID_CFG" ]]; then
    [[ -z "${MAINBOARD_UUID:-}" ]] && MAINBOARD_UUID="$(extract_uuid_from_canuid "$CANUID_CFG" "mcu")"
    [[ -z "${TOOLHEAD_UUID:-}" ]] && TOOLHEAD_UUID="$(extract_uuid_from_canuid "$CANUID_CFG" "mcu EECAN")"
    echo "Using UUID fallback values from $CANUID_CFG"
  fi
fi

is_valid_uuid "${MAINBOARD_UUID:-}" || { echo "MAINBOARD_UUID is required and must be 12 hex chars" >&2; exit 1; }
is_valid_uuid "${TOOLHEAD_UUID:-}" || { echo "TOOLHEAD_UUID is required and must be 12 hex chars" >&2; exit 1; }

PROFILE_DIR="${PROFILE_DIR:-$REPO_ROOT/config/support/mcu/mcu-firmware-configurations}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/out/mcu}"
CAN_IFACE="${CAN_IFACE:-can0}"

"$SCRIPT_DIR/build_klipper_mcus.sh" \
  --klipper-dir "$KLIPPER_DIR" \
  --profile-dir "$PROFILE_DIR" \
  --output-dir "$OUTPUT_DIR"

"$SCRIPT_DIR/flash_klipper_mcus_katapult.sh" \
  --can-iface "$CAN_IFACE" \
  --output-dir "$OUTPUT_DIR" \
  --mainboard-uuid "$MAINBOARD_UUID" \
  --toolhead-uuid "$TOOLHEAD_UUID"

if [[ "$UPDATE_CANUID_CFG" -eq 1 ]]; then
  mkdir -p "$REPO_ROOT/config/local"
  cat > "$REPO_ROOT/config/local/canuid.cfg" <<EOF
[mcu]
canbus_uuid:${MAINBOARD_UUID}
[mcu EECAN]
canbus_uuid:${TOOLHEAD_UUID}
EOF
  echo "Updated $REPO_ROOT/config/local/canuid.cfg"
fi

echo "Done. Both MCUs were built and flashed via Katapult workflow."
