#!/usr/bin/env bash
#
# freeThinker Phase 0 — read-only printer state capture.
#
# Run this ON a stock (or partially-modified) Eryone Thinker X400 over SSH.
# It modifies NOTHING. It collects the facts needed to design the
# migrate-to-mainline path, in particular:
#   - whether ~/klipper / ~/moonraker / ~/KlipperScreen are git repos and
#     what remotes/HEAD they point at (stock ships hand-edited copies),
#   - the MCU firmware version(s) reported in klippy.log — this decides
#     whether the host can move to mainline WITHOUT reflashing the MCUs,
#   - installed systemd services (incl. any Eryone farm/cloud/phone-home),
#   - the printer_data/config layout and which eryone_* extras are present.
#
# Usage (on the printer):
#   wget -qO- https://raw.githubusercontent.com/jpapiez/freeThinker/main/scripts/migrate/00_capture_printer_state.sh | bash
# or, if the repo is already cloned:
#   bash ~/freeThinker/scripts/migrate/00_capture_printer_state.sh
#
# Output: a single report file under the current directory:
#   freethinker-recon-<host>-<timestamp>.txt
# Send that file back so the migration script can be pinned correctly.

set -u

TS="$(date +%Y%m%d-%H%M%S)"
HOST="$(hostname 2>/dev/null || echo unknown)"
REPORT="$PWD/freethinker-recon-${HOST}-${TS}.txt"

# All output is tee'd to the report file.
exec > >(tee "$REPORT") 2>&1

section() { printf '\n========== %s ==========\n' "$*"; }
note()    { printf '  %s\n' "$*"; }

section "freeThinker recon"
note "timestamp : $TS"
note "host      : $HOST"
note "report    : $REPORT"

# ---------------------------------------------------------------------------
section "OS / platform"
uname -a || true
[ -r /etc/os-release ] && cat /etc/os-release || note "no /etc/os-release"
note "uptime: $(uptime 2>/dev/null || true)"

# ---------------------------------------------------------------------------
section "User / home"
WHOAMI="$(id -un 2>/dev/null || echo unknown)"
note "current user: $WHOAMI"
# Best-effort detection of the user running klipper.
KUSER=""
if command -v systemctl >/dev/null 2>&1; then
  KUSER="$(systemctl show -p User --value klipper 2>/dev/null || true)"
fi
[ -z "$KUSER" ] && KUSER="$WHOAMI"
note "klipper service user: $KUSER"
KHOME="$(getent passwd "$KUSER" 2>/dev/null | cut -d: -f6)"
[ -z "$KHOME" ] && KHOME="$HOME"
note "klipper home: $KHOME"

# ---------------------------------------------------------------------------
section "Python / toolchain"
for c in python3 git make gcc arm-none-eabi-gcc; do
  if command -v "$c" >/dev/null 2>&1; then
    note "$c: $("$c" --version 2>&1 | head -n1)"
  else
    note "$c: NOT FOUND"
  fi
done

# ---------------------------------------------------------------------------
section "Git state of host components"
for d in klipper moonraker KlipperScreen mainsail moonraker-timelapse; do
  path="$KHOME/$d"
  printf '\n-- %s --\n' "$path"
  if [ ! -d "$path" ]; then
    note "absent"
    continue
  fi
  if [ -d "$path/.git" ]; then
    note "is a git repo"
    note "remote: $(git -C "$path" remote -v 2>/dev/null | tr '\n' '; ')"
    note "HEAD:   $(git -C "$path" rev-parse HEAD 2>/dev/null)"
    note "branch: $(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    note "describe: $(git -C "$path" describe --tags --always --dirty 2>/dev/null)"
    dirty="$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    note "uncommitted changes: $dirty files"
    if [ "$dirty" != "0" ]; then
      note "modified files (first 40):"
      git -C "$path" status --porcelain 2>/dev/null | head -n 40 | sed 's/^/    /'
    fi
  else
    note "NOT a git repo (likely hand-edited vendor copy)"
  fi
done

# ---------------------------------------------------------------------------
section "Klipper host version"
if [ -x "$KHOME/klipper/scripts/get_version.py" ]; then
  ( cd "$KHOME/klipper" && python3 scripts/get_version.py 2>/dev/null ) || true
fi
[ -r "$KHOME/klipper/klippy/.version" ] && note ".version: $(cat "$KHOME/klipper/klippy/.version")"

# ---------------------------------------------------------------------------
section "MCU firmware versions (from klippy.log) — drives no-flash decision"
KLOG=""
for cand in \
  "$KHOME/printer_data/logs/klippy.log" \
  "$KHOME/klipper_logs/klippy.log" \
  "/var/log/klipper/klippy.log"; do
  [ -r "$cand" ] && KLOG="$cand" && break
done
if [ -n "$KLOG" ]; then
  note "log: $KLOG"
  note "--- 'mcu ... version' lines (last occurrences) ---"
  grep -aoE "mcu '[^']*' .*version: [^ ]+" "$KLOG" 2>/dev/null | tail -n 20 | sed 's/^/    /' || true
  note "--- 'Loaded MCU' / 'Starting Klipper' lines ---"
  grep -aE "Loaded MCU|Starting Klipper|^Version:" "$KLOG" 2>/dev/null | tail -n 20 | sed 's/^/    /' || true
  note "--- mcu build versions reported by firmware ---"
  grep -aoE "version=[^ ]+ build_versions=[^\"]*" "$KLOG" 2>/dev/null | tail -n 10 | sed 's/^/    /' || true
else
  note "klippy.log not found in known locations"
fi

# ---------------------------------------------------------------------------
section "Eryone extras present in klippy/extras"
if [ -d "$KHOME/klipper/klippy/extras" ]; then
  ls -1 "$KHOME/klipper/klippy/extras" 2>/dev/null \
    | grep -iE "eryone|rc522|pressure|plr" | sed 's/^/    /' || note "none matched"
fi

section "Eryone components present in moonraker/components"
if [ -d "$KHOME/moonraker/moonraker/components" ]; then
  ls -1 "$KHOME/moonraker/moonraker/components" 2>/dev/null \
    | grep -iE "eryone|metadata|file_manager" | sed 's/^/    /' || note "none matched"
fi

# ---------------------------------------------------------------------------
section "Systemd services (klipper stack + suspicious vendor services)"
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-units --type=service --all --no-pager --no-legend 2>/dev/null \
    | grep -iE "klipper|moonraker|klipperscreen|crowsnest|mainsail|eryone|farm|cloud|frp|obico|mks" \
    | sed 's/^/    /' || note "no matching services"
else
  note "systemctl unavailable"
fi

# ---------------------------------------------------------------------------
section "printer_data/config tree"
CFG="$KHOME/printer_data/config"
if [ -d "$CFG" ]; then
  note "config dir: $CFG"
  ls -la "$CFG" 2>/dev/null | sed 's/^/    /'
  printf '\n-- [include ...] lines in printer.cfg --\n'
  [ -r "$CFG/printer.cfg" ] && grep -aE "^\s*\[include" "$CFG/printer.cfg" 2>/dev/null | sed 's/^/    /'
  printf '\n-- update_manager blocks in moonraker.conf --\n'
  [ -r "$CFG/moonraker.conf" ] && grep -aE "^\s*\[update_manager" "$CFG/moonraker.conf" 2>/dev/null | sed 's/^/    /'
else
  note "no printer_data/config at $CFG"
fi

# ---------------------------------------------------------------------------
section "CAN bus state (toolhead detection)"
if command -v ip >/dev/null 2>&1; then
  ip -details link show 2>/dev/null | grep -A2 -iE "can" | sed 's/^/    /' || note "no CAN interface"
fi

section "DONE"
note "Report written to: $REPORT"
note "Send this file back to drive the migration-script pinning."
