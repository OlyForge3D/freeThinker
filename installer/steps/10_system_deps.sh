#!/usr/bin/env bash

for cmd in git python3 curl; do
  require_cmd "$cmd"
done

apt_cache_updated=0

ensure_optional_deb_package() {
  local pkg="$1"
  local reason="$2"

  if command -v dpkg-query >/dev/null 2>&1; then
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
      return 0
    fi
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    log_warn "Missing optional package '$pkg' ($reason); apt-get is unavailable."
    return 0
  fi

  if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    log_warn "Missing optional package '$pkg' ($reason); install it manually."
    return 0
  fi

  if [[ "$apt_cache_updated" -eq 0 ]]; then
    if ! run_root_cmd env DEBIAN_FRONTEND=noninteractive apt-get update; then
      log_warn "Unable to run apt-get update; skipping optional package '$pkg'."
      return 0
    fi
    apt_cache_updated=1
  fi

  if run_root_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
    log_info "Installed optional package '$pkg' ($reason)."
  else
    log_warn "Failed to install optional package '$pkg' ($reason); install manually."
  fi
}

if ! command -v msgfmt >/dev/null 2>&1; then
  log_warn "msgfmt not found; locale compilation will be skipped until gettext is installed."
fi

if ! command -v systemctl >/dev/null 2>&1; then
  log_warn "systemctl not found; service management steps will be skipped."
fi

if ! python3 -c 'import cv2, numpy' >/dev/null 2>&1; then
  ensure_optional_deb_package "python3-opencv" "camera bed detection for DETECT_BED_OBJECT"
fi

if ! python3 -c 'import cv2, numpy' >/dev/null 2>&1; then
  log_warn "DETECT_BED_OBJECT will be unavailable until python3-opencv is installed."
fi
