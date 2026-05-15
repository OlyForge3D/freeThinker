#!/usr/bin/env bash

panels_src="$REPO_ROOT/klipperscreen-eryone/panels"
panels_dst="$KLIPPERSCREEN_DIR/panels"

if [[ -d "$panels_src" ]]; then
  for src in "$panels_src"/eryone_*.py; do
    [[ -f "$src" ]] || continue
    link_file "$src" "$panels_dst/$(basename "$src")"
  done
fi
