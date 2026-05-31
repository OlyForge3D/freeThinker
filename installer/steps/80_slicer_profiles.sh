#!/usr/bin/env bash

# File: installer/steps/80_slicer_profiles.sh
# Purpose: Install bundled slicer profiles into printer_data config.
#

profiles_dst="$CONFIG_DIR/profiles"
mkdir -p "$profiles_dst"

if [[ -f "$REPO_ROOT/profiles/Eryone.json" ]]; then
  install_file "$REPO_ROOT/profiles/Eryone.json" "$profiles_dst/Eryone.json" 0644
fi

if [[ -d "$REPO_ROOT/profiles/Eryone" ]]; then
  rm -rf "$profiles_dst/Eryone"
  cp -R "$REPO_ROOT/profiles/Eryone" "$profiles_dst/Eryone"
  log_info "Installed slicer profiles to $profiles_dst/Eryone"
fi
