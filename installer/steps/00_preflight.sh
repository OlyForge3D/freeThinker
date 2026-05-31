#!/usr/bin/env bash

# File: installer/steps/00_preflight.sh
# Purpose: Detect environment, validate prerequisites, and optionally run fresh-rebuild flow.
#

confirm_fresh_rebuild() {
	if [[ "$FORCE" -eq 1 ]]; then
		log_warn "--force supplied: skipping typed confirmation for fresh rebuild"
		return 0
	fi

	[[ -t 0 ]] || fail "--fresh-rebuild requires an interactive terminal (or pass --force)"

	local answer
	log_warn "Fresh rebuild will stop services and remove existing Klipper stack directories."
	log_warn "An archive is created first at ~/freeThinker-archive/."
	read -r -p "Type REBUILD_X400 to continue: " answer
	[[ "$answer" == "REBUILD_X400" ]] || fail "Fresh rebuild cancelled"
}

archive_existing_stack() {
	local stamp archive_root archive_file
	stamp="$(date +%Y%m%d-%H%M%S)"
	archive_root="$PRINTER_HOME/freeThinker-archive"
	archive_file="$archive_root/x400-stack-$stamp.tar.gz"

	mkdir -p "$archive_root"

	local -a rel_paths=(
		"printer_data"
		"klipper"
		"moonraker"
		"KlipperScreen"
		"mainsail"
		"mainsail-config"
		"crowsnest"
	)

	local -a existing_paths=()
	local rel
	for rel in "${rel_paths[@]}"; do
		[[ -e "$PRINTER_HOME/$rel" ]] && existing_paths+=("$rel")
	done

	if [[ "${#existing_paths[@]}" -gt 0 ]]; then
		tar -C "$PRINTER_HOME" -czf "$archive_file" "${existing_paths[@]}"
		log_info "Archived existing user stack to $archive_file"
	else
		log_warn "No user stack directories found to archive under $PRINTER_HOME"
	fi

	local sys_archive="$archive_root/x400-system-$stamp.tar.gz"
	if command -v systemctl >/dev/null 2>&1; then
		run_root_cmd tar -czf "$sys_archive" \
			/etc/systemd/system/klipper.service \
			/etc/systemd/system/moonraker.service \
			/etc/systemd/system/KlipperScreen.service \
			/etc/systemd/network/10-can.link \
			/etc/systemd/network/20-can0.network \
			/etc/network/interfaces.d/can0 2>/dev/null || true
		[[ -f "$sys_archive" ]] && log_info "Archived system config to $sys_archive"
	fi
}

run_fresh_rebuild_flow() {
	confirm_fresh_rebuild
	archive_existing_stack

	if command -v systemctl >/dev/null 2>&1; then
		run_root_cmd systemctl stop klipper 2>/dev/null || true
		run_root_cmd systemctl stop moonraker 2>/dev/null || true
		run_root_cmd systemctl stop KlipperScreen.service 2>/dev/null || true
	fi

	rm -rf "$PRINTER_HOME/klipper" "$PRINTER_HOME/moonraker" "$PRINTER_HOME/KlipperScreen" "$PRINTER_HOME/mainsail" "$PRINTER_HOME/crowsnest"
	rm -rf "$PRINTER_HOME/printer_data/config" "$PRINTER_HOME/printer_data/comms" "$PRINTER_HOME/printer_data/systemd"

	if [[ -x "$PRINTER_HOME/kiauh/kiauh.sh" ]]; then
		log_info "Launching KIAUH. Install Klipper, Moonraker, Mainsail, KlipperScreen, and Crowsnest, then exit KIAUH to continue."
		"$PRINTER_HOME/kiauh/kiauh.sh"
	else
		fail "KIAUH not found at $PRINTER_HOME/kiauh/kiauh.sh. Install KIAUH, reinstall base stack, then re-run install.sh"
	fi
}

require_cmd awk
require_cmd sed
require_cmd install
require_cmd ln

PRINTER_USER="$(detect_printer_user)"
PRINTER_HOME="$(resolve_home_for_user "$PRINTER_USER")"
PRINTER_DATA_DIR="${PRINTER_HOME}/printer_data"
CONFIG_DIR="${PRINTER_DATA_DIR}/config"
KLIPPER_DIR="${PRINTER_HOME}/klipper"
MOONRAKER_DIR="${PRINTER_HOME}/moonraker"
KLIPPERSCREEN_DIR="${PRINTER_HOME}/KlipperScreen"

export PRINTER_USER PRINTER_HOME PRINTER_DATA_DIR CONFIG_DIR KLIPPER_DIR MOONRAKER_DIR KLIPPERSCREEN_DIR

if [[ "${FRESH_REBUILD:-0}" == "1" ]]; then
	run_fresh_rebuild_flow
fi

[[ -d "$KLIPPER_DIR/klippy/extras" ]] || { [[ "$FORCE" -eq 1 ]] || fail "Klipper extras path not found: $KLIPPER_DIR/klippy/extras"; }
[[ -d "$MOONRAKER_DIR/moonraker/components" ]] || { [[ "$FORCE" -eq 1 ]] || fail "Moonraker components path not found: $MOONRAKER_DIR/moonraker/components"; }
[[ -d "$KLIPPERSCREEN_DIR/panels" ]] || { [[ "$FORCE" -eq 1 ]] || fail "KlipperScreen panels path not found: $KLIPPERSCREEN_DIR/panels"; }

mkdir -p "$CONFIG_DIR"
mkdir -p "$REPO_ROOT/installer/.state"

log_info "Preflight complete"
log_info "  printer_user=$PRINTER_USER"
log_info "  printer_home=$PRINTER_HOME"
log_info "  config_dir=$CONFIG_DIR"
log_info "  variant=$VARIANT_ID (EECAN_INCLUDE=$EECAN_INCLUDE)"
