#!/usr/bin/env bash

components_src="$REPO_ROOT/moonraker-eryone/components"
components_dst="$MOONRAKER_DIR/moonraker/components"

if [[ -d "$components_src" ]]; then
  for src in "$components_src"/eryone_*.py; do
    [[ -f "$src" ]] || continue
    link_file "$src" "$components_dst/$(basename "$src")"
  done
fi
