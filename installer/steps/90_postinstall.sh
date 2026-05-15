#!/usr/bin/env bash

if [[ "${RESTART_SERVICES:-0}" == "1" ]]; then
  log_info "Restarting klipper and moonraker services"
  run_root_cmd systemctl restart klipper
  run_root_cmd systemctl restart moonraker
  if run_root_cmd systemctl list-unit-files "KlipperScreen.service" >/dev/null 2>&1; then
    run_root_cmd systemctl restart KlipperScreen.service
  else
    log_info "KlipperScreen.service not present; skipped restart"
  fi
else
  log_info "Skipping service restart (set RESTART_SERVICES=1 to enable)"
fi

log_info "Overlay files installed."
