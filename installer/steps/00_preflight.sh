#!/usr/bin/env bash

require_cmd awk
require_cmd sed
require_cmd install
require_cmd ln

PRINTER_USER="$(detect_printer_user)"
PRINTER_HOME="$(resolve_home_for_user "$PRINTER_USER")"
PRINTER_DATA_DIR="${PRINTER_HOME}/printer_data"
CONFIG_DIR="${PRINTER_DATA_DIR}/config"
KLIPPER_DIR="${PRINTER_HOME}/klipper"
MOONRAKER_DIR="${PRINTER_HOME}/moonraker"
KLIPPERSCREEN_DIR="${PRINTER_HOME}/KlipperScreen"

export PRINTER_USER PRINTER_HOME PRINTER_DATA_DIR CONFIG_DIR KLIPPER_DIR MOONRAKER_DIR KLIPPERSCREEN_DIR

[[ -d "$KLIPPER_DIR/klippy/extras" ]] || { [[ "$FORCE" -eq 1 ]] || fail "Klipper extras path not found: $KLIPPER_DIR/klippy/extras"; }
[[ -d "$MOONRAKER_DIR/moonraker/components" ]] || { [[ "$FORCE" -eq 1 ]] || fail "Moonraker components path not found: $MOONRAKER_DIR/moonraker/components"; }
[[ -d "$KLIPPERSCREEN_DIR/panels" ]] || { [[ "$FORCE" -eq 1 ]] || fail "KlipperScreen panels path not found: $KLIPPERSCREEN_DIR/panels"; }

mkdir -p "$CONFIG_DIR"
mkdir -p "$REPO_ROOT/installer/.state"

log_info "Preflight complete"
log_info "  printer_user=$PRINTER_USER"
log_info "  printer_home=$PRINTER_HOME"
log_info "  config_dir=$CONFIG_DIR"
log_info "  variant=$VARIANT_ID (EECAN_INCLUDE=$EECAN_INCLUDE)"
