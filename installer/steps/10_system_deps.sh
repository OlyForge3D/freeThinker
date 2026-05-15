for cmd in git python3; do
  require_cmd "$cmd"
done

if ! command -v msgfmt >/dev/null 2>&1; then
  log_warn "msgfmt not found; locale compilation will be skipped until gettext is installed."
fi

if ! command -v systemctl >/dev/null 2>&1; then
  log_warn "systemctl not found; service management steps will be skipped."
fi
