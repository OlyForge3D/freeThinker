#!/usr/bin/env bash

# File: installer/steps/90_postinstall.sh
# Purpose: Run post-install actions such as service restart and optional MCU flash.
#

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

if [[ "${FLASH_MCUS:-0}" == "1" ]]; then
  mcu_env="${MCU_ENV_FILE:-$REPO_ROOT/config/support/mcu/mcu-update.env}"
  log_info "Running MCU flash workflow using env file: $mcu_env"
  "$REPO_ROOT/scripts/mcu/update_both_mcus.sh" --env-file "$mcu_env"
fi
