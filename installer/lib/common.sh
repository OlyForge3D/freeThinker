#!/usr/bin/env bash

# File: installer/lib/common.sh
# Purpose: Shared installer utility functions for logging, templating, and file operations.
#

log_info() {
  printf '[thinker-x400] %s\n' "$*"
}

log_warn() {
  printf '[thinker-x400][warn] %s\n' "$*" >&2
}

fail() {
  printf '[thinker-x400][error] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

detect_printer_user() {
  if [[ -n "${INSTALL_PRINTER_USER:-}" ]]; then
    printf '%s\n' "$INSTALL_PRINTER_USER"
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    local service_user
    service_user="$(systemctl show -p User --value klipper 2>/dev/null || true)"
    if [[ -n "$service_user" && "$service_user" != "root" ]]; then
      printf '%s\n' "$service_user"
      return 0
    fi
  fi
  id -un
}

resolve_home_for_user() {
  local user="$1"
  if command -v getent >/dev/null 2>&1; then
    local home
    home="$(getent passwd "$user" | cut -d: -f6 || true)"
    if [[ -n "$home" ]]; then
      printf '%s\n' "$home"
      return 0
    fi
  fi
  eval "printf '%s\n' ~$user"
}

ensure_backup() {
  local target="$1"
  local backup="${target}.bak.thinker-x400"
  if [[ -e "$target" && ! -L "$target" && ! -e "$backup" ]]; then
    cp -a "$target" "$backup"
    log_info "Backed up $target -> $backup"
  fi
}

link_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    local cur
    cur="$(readlink "$dst")"
    if [[ "$cur" == "$src" ]]; then
      return 0
    fi
    rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    ensure_backup "$dst"
    rm -rf "$dst"
  fi
  ln -s "$src" "$dst"
  log_info "Linked $dst -> $src"
}

install_file() {
  local src="$1"
  local dst="$2"
  local mode="${3:-0644}"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then
    ensure_backup "$dst"
  fi
  install -m "$mode" "$src" "$dst"
  log_info "Installed $dst"
}

install_file_if_missing() {
  local src="$1"
  local dst="$2"
  local mode="${3:-0644}"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then
    log_info "Preserving existing $dst"
    return 0
  fi
  install -m "$mode" "$src" "$dst"
  log_info "Installed default $dst"
}

render_template() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  awk '
  {
    line=$0
    gsub(/\{\{PRINTER_USER\}\}/, ENVIRON["PRINTER_USER"], line)
    gsub(/\{\{PRINTER_HOME\}\}/, ENVIRON["PRINTER_HOME"], line)
    gsub(/\{\{PRINTER_DATA_DIR\}\}/, ENVIRON["PRINTER_DATA_DIR"], line)
    gsub(/\{\{CONFIG_DIR\}\}/, ENVIRON["CONFIG_DIR"], line)
    gsub(/\{\{EECAN_INCLUDE\}\}/, ENVIRON["EECAN_INCLUDE"], line)
    gsub(/\{\{REPO_ROOT\}\}/, ENVIRON["REPO_ROOT"], line)
    print line
  }' "$src" > "$dst"
}

append_line_if_missing() {
  local file="$1"
  local line="$2"
  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '\n%s\n' "$line" >> "$file"
    log_info "Appended to $file: $line"
  fi
}

validate_canuid_cfg() {
  local cfg="$1"
  [[ -f "$cfg" ]] || fail "Missing required config: $cfg"

  local main_uuid tool_uuid
  main_uuid="$(awk -F: '/^\[mcu\]/{section="main";next} /^\[/{section=""} section=="main" && /^canbus_uuid:/{gsub(/[[:space:]]/,"",$2); print tolower($2); exit}' "$cfg")"
  tool_uuid="$(awk -F: '/^\[mcu EECAN\]/{section="tool";next} /^\[/{section=""} section=="tool" && /^canbus_uuid:/{gsub(/[[:space:]]/,"",$2); print tolower($2); exit}' "$cfg")"

  [[ -n "$main_uuid" ]] || fail "Missing [mcu] canbus_uuid in $cfg"
  [[ -n "$tool_uuid" ]] || fail "Missing [mcu EECAN] canbus_uuid in $cfg"

  [[ "$main_uuid" =~ ^[0-9a-f]{12}$ ]] || fail "Invalid [mcu] canbus_uuid format in $cfg: $main_uuid"
  [[ "$tool_uuid" =~ ^[0-9a-f]{12}$ ]] || fail "Invalid [mcu EECAN] canbus_uuid format in $cfg: $tool_uuid"

  [[ "$main_uuid" != "000000000000" ]] || fail "Template placeholder UUID found for [mcu] in $cfg"
  [[ "$tool_uuid" != "000000000000" ]] || fail "Template placeholder UUID found for [mcu EECAN] in $cfg"
}

run_root_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "Need root privileges for: $*"
  fi
}
