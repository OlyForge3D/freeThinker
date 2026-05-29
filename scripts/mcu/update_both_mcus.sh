#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV_FILE="${ENV_FILE:-$REPO_ROOT/config/mcu-update.env}"
UPDATE_CANUID_CFG=0

usage() {
  cat <<'EOF'
Usage: ./scripts/mcu/update_both_mcus.sh [options]

Options:
  --env-file <path>         Path to env file (default: config/mcu-update.env)
  --update-canuid-cfg       Rewrite config/canuid.cfg with provided UUIDs
  -h, --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="$2"
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
  echo "Copy config/mcu-update.env.example to config/mcu-update.env and edit values." >&2
  exit 1
}

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${KLIPPER_DIR:?KLIPPER_DIR is required in env file}"
: "${MAINBOARD_UUID:?MAINBOARD_UUID is required in env file}"
: "${TOOLHEAD_UUID:?TOOLHEAD_UUID is required in env file}"

PROFILE_DIR="${PROFILE_DIR:-$REPO_ROOT/config/mcu-firmware-configurations}"
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
  cat > "$REPO_ROOT/config/canuid.cfg" <<EOF
[mcu]
canbus_uuid:${MAINBOARD_UUID}
[mcu EECAN]
canbus_uuid:${TOOLHEAD_UUID}
EOF
  echo "Updated $REPO_ROOT/config/canuid.cfg"
fi

echo "Done. Both MCUs were built and flashed via Katapult workflow."
