#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
source "$REPO_ROOT/installer/lib/common.sh"

VARIANT=""
INSTALL_PRINTER_USER=""
FORCE=0

usage() {
  cat <<'EOF'
Usage: ./install.sh --variant <x400_300|x400_350> [options]

Options:
  --variant <id>         Required variant id
  --printer-user <user>  Override detected printer user
  --force                Continue even if preflight warnings are detected
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)
      VARIANT="${2:-}"
      shift 2
      ;;
    --printer-user)
      INSTALL_PRINTER_USER="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$VARIANT" ]] || fail "--variant is required (x400_300 or x400_350)"
VARIANT_FILE="$REPO_ROOT/installer/variants/${VARIANT}.env"
[[ -f "$VARIANT_FILE" ]] || fail "Unknown variant '$VARIANT' (missing $VARIANT_FILE)"

# shellcheck disable=SC1090
source "$VARIANT_FILE"
export VARIANT VARIANT_ID BED_SIZE_X BED_SIZE_Y TOOLHEAD_REV HOTEND_MAX_TEMP EECAN_INCLUDE PRESSURE_SENSOR_FIRMWARE
export INSTALL_PRINTER_USER FORCE

log_info "Installing thinker-x400 overlay (variant: $VARIANT_ID)"

for step in "$REPO_ROOT"/installer/steps/[0-9][0-9]_*.sh; do
  log_info "Running step $(basename "$step")"
  # shellcheck disable=SC1090
  source "$step"
done

log_info "Install complete."
