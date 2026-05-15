#!/usr/bin/env bash

template_dir="$REPO_ROOT/config/templates"

# Install static config snippets
for src in "$REPO_ROOT"/config/*; do
  base="$(basename "$src")"
  case "$base" in
    README.md|templates|scripts|printer.cfg|moonraker.conf)
      continue
      ;;
  esac
  [[ -f "$src" ]] || continue
  mode=0644
  [[ "$base" == "plr.sh" ]] && mode=0755
  tmp_file="$(mktemp)"
  render_template "$src" "$tmp_file"
  install_file "$tmp_file" "$CONFIG_DIR/$base" "$mode"
  rm -f "$tmp_file"
done

# Install helper scripts used by gcode_shell_command entries.
if [[ -d "$REPO_ROOT/config/scripts" ]]; then
  mkdir -p "$CONFIG_DIR/scripts"
  for src in "$REPO_ROOT"/config/scripts/*.sh; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    tmp_file="$(mktemp)"
    render_template "$src" "$tmp_file"
    install_file "$tmp_file" "$CONFIG_DIR/scripts/$base" 0755
    rm -f "$tmp_file"
  done
fi

# Render printer.cfg from template and preserve SAVE_CONFIG block when present.
tmp_printer="$(mktemp)"
render_template "$template_dir/printer.cfg.j2" "$tmp_printer"
if [[ -f "$CONFIG_DIR/printer.cfg" ]] && grep -q '^#\*# <---------------------- SAVE_CONFIG ---------------------->' "$CONFIG_DIR/printer.cfg"; then
  awk '/^#\*# <---------------------- SAVE_CONFIG ---------------------->/{flag=1} flag{print}' "$CONFIG_DIR/printer.cfg" >> "$tmp_printer"
fi
install_file "$tmp_printer" "$CONFIG_DIR/printer.cfg" 0644
rm -f "$tmp_printer"

# Render Moonraker overlay snippet and ensure include exists.
render_template "$template_dir/moonraker.thinker-x400.conf.j2" "$CONFIG_DIR/moonraker.thinker-x400.conf"
append_line_if_missing "$CONFIG_DIR/moonraker.conf" "[include moonraker.thinker-x400.conf]"
