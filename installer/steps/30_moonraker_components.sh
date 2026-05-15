#!/usr/bin/env bash

components_src="$REPO_ROOT/moonraker-eryone/components"
components_dst="$MOONRAKER_DIR/moonraker/components"

if [[ -d "$components_src" ]]; then
  # Remove managed symlinks for components that no longer exist in this repo.
  for dst in "$components_dst"/eryone_*.py; do
    [[ -L "$dst" ]] || continue
    target="$(readlink "$dst")"
    [[ "$target" == "$components_src/"* ]] || continue
    [[ -f "$target" ]] && continue
    rm -f "$dst"
    log_info "Removed stale Moonraker component symlink $dst"
  done

  for src in "$components_src"/eryone_*.py; do
    [[ -f "$src" ]] || continue
    link_file "$src" "$components_dst/$(basename "$src")"
  done
fi
