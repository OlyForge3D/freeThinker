extras_src="$REPO_ROOT/klipper-eryone/extras"
extras_dst="$KLIPPER_DIR/klippy/extras"

if [[ -d "$extras_src" ]]; then
  for src in "$extras_src"/eryone_*.py; do
    [[ -f "$src" ]] || continue
    link_file "$src" "$extras_dst/$(basename "$src")"
  done
fi

if [[ "${APPLY_KLIPPER_PATCHES:-0}" == "1" ]]; then
  log_warn "APPLY_KLIPPER_PATCHES=1 set; attempting to apply patch queue with git am"
  for patch in "$REPO_ROOT"/klipper-eryone/patches/000*.patch; do
    [[ -f "$patch" ]] || continue
    git -C "$KLIPPER_DIR" am "$patch"
  done
else
  log_info "Skipping Klipper patch queue (set APPLY_KLIPPER_PATCHES=1 to apply)"
fi
