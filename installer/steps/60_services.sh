#!/usr/bin/env bash

if [[ "${ENABLE_OPTIONAL_SERVICES:-0}" != "1" ]]; then
  log_info "Skipping optional services (set ENABLE_OPTIONAL_SERVICES=1 to enable)"
  return 0
fi

command -v systemctl >/dev/null 2>&1 || { log_warn "systemctl not available; skipping service installation"; return 0; }

for template in "$REPO_ROOT"/services/*.service.in; do
  [[ -f "$template" ]] || continue
  service_name="$(basename "$template" .in)"
  tmp_file="$(mktemp)"
  render_template "$template" "$tmp_file"
  run_root_cmd install -m 0644 "$tmp_file" "/etc/systemd/system/$service_name"
  rm -f "$tmp_file"
  run_root_cmd systemctl daemon-reload
  run_root_cmd systemctl enable --now "$service_name"
  log_info "Installed and enabled $service_name"
done
