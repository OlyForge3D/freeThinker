if [[ "${RESTART_SERVICES:-0}" == "1" ]]; then
  log_info "Restarting klipper and moonraker services"
  run_root_cmd systemctl restart klipper
  run_root_cmd systemctl restart moonraker
  # KlipperScreen service name differs on some installs; keep best-effort.
  run_root_cmd systemctl restart KlipperScreen.service || true
else
  log_info "Skipping service restart (set RESTART_SERVICES=1 to enable)"
fi

log_info "Overlay files installed."
