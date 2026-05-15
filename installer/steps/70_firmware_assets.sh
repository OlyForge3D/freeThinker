#!/usr/bin/env bash

firmware_src="$REPO_ROOT/klipper-eryone/firmware"
firmware_dst="$CONFIG_DIR/firmware/thinker-x400"

mkdir -p "$firmware_dst"

if [[ -f "$firmware_src/MANIFEST.json" ]]; then
  install_file "$firmware_src/MANIFEST.json" "$firmware_dst/MANIFEST.json" 0644
fi

if [[ -n "${PRESSURE_SENSOR_FIRMWARE:-}" ]]; then
  selected="$firmware_src/$PRESSURE_SENSOR_FIRMWARE"
  [[ -f "$selected" ]] || fail "Missing variant firmware: $selected"
  install_file "$selected" "$firmware_dst/$(basename "$selected")" 0644
fi

for bin in "$firmware_src"/*.{hex,bin,uf2}; do
  [[ -f "$bin" ]] || continue
  install_file "$bin" "$firmware_dst/$(basename "$bin")" 0644
done
