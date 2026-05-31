#!/usr/bin/env bash

# File: install.sh
# Purpose: Entry point that applies variant-aware overlay installation steps.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
source "$REPO_ROOT/installer/lib/common.sh"

VARIANT=""
HOTEND=""
INSTALL_PRINTER_USER=""
FORCE=0
FRESH_REBUILD=0
FLASH_MCUS=0
MCU_ENV_FILE=""
HOTEND_GUIDE_URL="https://eryonewiki.com/en/home/HotendUpgradeto350%C2%B0CAssemblyProcess"

apply_hotend_profile() {
  case "$1" in
    300)
      HOTEND_MAX_TEMP=300
      TOOLHEAD_REV=standard
      EECAN_INCLUDE=EECAN1_300.cfg
      PRESSURE_SENSOR_FIRMWARE=stm32_pressure_sensor_300.hex
      ;;
    350)
      HOTEND_MAX_TEMP=350
      TOOLHEAD_REV=high_temp_adc_v1
      EECAN_INCLUDE=EECAN1_350.cfg
      PRESSURE_SENSOR_FIRMWARE=stm32_pressure_sensor_350.hex
      ;;
    *)
      fail "Invalid --hotend value '$1' (expected 300 or 350)"
      ;;
  esac
}

prompt_hotend_selection() {
  local selected
  log_info "Select installed hotend type:"
  log_info "  300 = standard hotend (max 300C)"
  log_info "  350 = high-temp hotend (max 350C)"
  log_info "Guide: $HOTEND_GUIDE_URL"
  while true; do
    read -r -p "Enter hotend type (300 or 350): " selected || fail "Unable to read hotend selection"
    case "$selected" in
      300|350)
        printf '%s\n' "$selected"
        return 0
        ;;
      *)
        log_warn "Invalid selection '$selected'. Please enter 300 or 350."
        ;;
    esac
  done
}

usage() {
  cat <<'EOF'
Usage: ./install.sh --variant <x400_300|x400_350> [options]

Options:
  --variant <id>         Required variant id
  --hotend <300|350>     Hotend type (required for non-interactive installs)
  --printer-user <user>  Override detected printer user
  --fresh-rebuild        Archive current stack and guide a clean base reinstall
  --flash-mcus           After install, run scripts/mcu/update_both_mcus.sh
  --mcu-env-file <path>  Env file for --flash-mcus (default: config/support/mcu/mcu-update.env)
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
    --hotend)
      HOTEND="${2:-}"
      shift 2
      ;;
    --printer-user)
      INSTALL_PRINTER_USER="${2:-}"
      shift 2
      ;;
    --fresh-rebuild)
      FRESH_REBUILD=1
      shift
      ;;
    --flash-mcus)
      FLASH_MCUS=1
      shift
      ;;
    --mcu-env-file)
      MCU_ENV_FILE="${2:-}"
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

if [[ -z "$HOTEND" ]]; then
  if [[ -t 0 ]]; then
    HOTEND="$(prompt_hotend_selection)"
  else
    fail "--hotend is required in non-interactive mode (300 or 350). See: $HOTEND_GUIDE_URL"
  fi
fi

apply_hotend_profile "$HOTEND"
export VARIANT VARIANT_ID BED_SIZE_X BED_SIZE_Y TOOLHEAD_REV HOTEND_MAX_TEMP EECAN_INCLUDE PRESSURE_SENSOR_FIRMWARE
export HOTEND INSTALL_PRINTER_USER FORCE FRESH_REBUILD FLASH_MCUS MCU_ENV_FILE

log_info "Installing thinker-x400 overlay (variant: $VARIANT_ID, hotend: ${HOTEND}C, fresh_rebuild=${FRESH_REBUILD}, flash_mcus=${FLASH_MCUS})"

for step in "$REPO_ROOT"/installer/steps/[0-9][0-9]_*.sh; do
  log_info "Running step $(basename "$step")"
  # shellcheck disable=SC1090
  source "$step"
done

log_info "Install complete."
