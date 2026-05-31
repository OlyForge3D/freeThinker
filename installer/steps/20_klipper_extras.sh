#!/usr/bin/env bash

# File: installer/steps/20_klipper_extras.sh
# Purpose: Install or update Klipper extra module symlinks.
#

extras_src="$REPO_ROOT/klipper-eryone/extras"
extras_dst="$KLIPPER_DIR/klippy/extras"

if [[ -d "$extras_src" ]]; then
  for src in "$extras_src"/eryone_*.py; do
    [[ -f "$src" ]] || continue
    link_file "$src" "$extras_dst/$(basename "$src")"
  done
fi

log_info "Klipper patch queue is empty; no upstream patches applied"
