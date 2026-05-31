#!/usr/bin/env bash

# File: uninstall.sh
# Purpose: Remove thinker-x400 overlay links/configuration from host.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
source "$REPO_ROOT/installer/lib/common.sh"

INSTALL_PRINTER_USER=""

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [--printer-user <user>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --printer-user)
      INSTALL_PRINTER_USER="${2:-}"
      shift 2
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

PRINTER_USER="$(detect_printer_user)"
PRINTER_HOME="$(resolve_home_for_user "$PRINTER_USER")"
PRINTER_DATA_DIR="${PRINTER_HOME}/printer_data"
CONFIG_DIR="${PRINTER_DATA_DIR}/config"
KLIPPER_DIR="${PRINTER_HOME}/klipper"
MOONRAKER_DIR="${PRINTER_HOME}/moonraker"
KLIPPERSCREEN_DIR="${PRINTER_HOME}/KlipperScreen"

log_info "Uninstalling thinker-x400 overlay for user: $PRINTER_USER"

remove_managed_symlink() {
  local path="$1"
  if [[ -L "$path" ]]; then
    local target
    target="$(readlink "$path")"
    if [[ "$target" == "$REPO_ROOT"* ]]; then
      rm -f "$path"
      log_info "Removed symlink $path"
    fi
  fi
}

for p in "$KLIPPER_DIR"/klippy/extras/eryone_*.py; do
  [[ -e "$p" || -L "$p" ]] || continue
  remove_managed_symlink "$p"
done
for p in "$MOONRAKER_DIR"/moonraker/components/eryone_*.py; do
  [[ -e "$p" || -L "$p" ]] || continue
  remove_managed_symlink "$p"
done
for p in "$KLIPPERSCREEN_DIR"/panels/eryone_*.py; do
  [[ -e "$p" || -L "$p" ]] || continue
  remove_managed_symlink "$p"
done

if [[ -f "$CONFIG_DIR/printer.cfg.bak.thinker-x400" ]]; then
  cp -a "$CONFIG_DIR/printer.cfg.bak.thinker-x400" "$CONFIG_DIR/printer.cfg"
  log_info "Restored printer.cfg from backup"
fi

if [[ -f "$CONFIG_DIR/moonraker.thinker-x400.conf" ]]; then
  rm -f "$CONFIG_DIR/moonraker.thinker-x400.conf"
  log_info "Removed moonraker.thinker-x400.conf"
fi

if [[ -f "$CONFIG_DIR/moonraker.conf" ]]; then
  sed -i'' '/^\[include moonraker\.thinker-x400\.conf\]$/d' "$CONFIG_DIR/moonraker.conf" || true
fi

log_info "Uninstall complete."
