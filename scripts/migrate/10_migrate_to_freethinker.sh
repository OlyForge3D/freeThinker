#!/bin/sh

# File: scripts/migrate/10_migrate_to_freethinker.sh
# Purpose: Migrate existing X400 host from legacy layout to freeThinker overlay.
#
# freeThinker migration — one-time migration of an Eryone Thinker X400 from the
# stock Eryone/Makerbase image to mainline Klipper + Moonraker + KlipperScreen,
# managed by the freeThinker overlay.
#
# One-liner (run ON THE PRINTER via SSH):
#   wget -qO- https://raw.githubusercontent.com/jpapiez/freeThinker/main/scripts/migrate/10_migrate_to_freethinker.sh | sh
# (or, if wget is unreliable on the vendor image, scp this file over and run it)
#
# Design goals (in priority order):
#   1. NUKE ALL PHONE-HOME / CLOUD-RELAY GARBAGE. The stock image runs a
#      `farm3d` MQTT relay (mq.py) that connects to a hardcoded remote broker
#      with embedded credentials and uploads files/snapshots via minio, plus an
#      ip-api.com geo lookup in rc.local. None of that survives this migration.
#   2. NO FLASHING FIRST. The toolhead/mainboard MCU firmware (2024 builds) is
#      left untouched; the Klipper *host* is pinned to a protocol-compatible
#      commit so the printer runs without reflashing. Reflashing is a separate,
#      explicit, opt-in step (see scripts/mcu/).
#   3. Replace vendor forks with mainline:
#        - ~/klipper        : NOT a git repo on stock (hand-edited). Custom
#                             extras are preserved, then a fresh mainline clone
#                             is pinned.
#        - ~/moonraker      : already on mainline (arksine) but dirty. Reset to
#                             a pinned mainline commit.
#        - ~/KlipperScreen  : heavy gitcode.com/xpp012 fork. Replaced with
#                             mainline KlipperScreen.
#   4. Register [update_manager freeThinker] so the overlay self-updates.
#   5. Hand off to the freeThinker installer to deploy configs/extras.
#   6. STANDARDIZE BOOTLOADER SOURCE ON KATAPULT. Legacy ~/CanBoot or
#      ~/canboot checkouts are migrated aside, then ~/katapult is cloned/
#      updated from upstream and becomes the canonical bootloader source.
#
# Idempotent and POSIX sh compatible. Privileged steps (systemd, /etc) degrade
# gracefully when not run as root; re-run with sudo to complete them.

set -eu

# --- Configuration -----------------------------------------------------------

PRINTER_USER="${PRINTER_USER:-mks}"
PRINTER_HOME="${PRINTER_HOME:-/home/$PRINTER_USER}"

KLIPPER_DIR="${KLIPPER_DIR:-$PRINTER_HOME/klipper}"
MOONRAKER_DIR="${MOONRAKER_DIR:-$PRINTER_HOME/moonraker}"
KLIPPERSCREEN_DIR="${KLIPPERSCREEN_DIR:-$PRINTER_HOME/KlipperScreen}"
FREETHINKER_DIR="${FREETHINKER_DIR:-$PRINTER_HOME/freeThinker}"
MOONRAKER_CONF="${MOONRAKER_CONF:-$PRINTER_HOME/printer_data/config/moonraker.conf}"
BACKUP_DIR="${BACKUP_DIR:-$PRINTER_HOME/freethinker-premigration-backup}"

MAINLINE_KLIPPER="${MAINLINE_KLIPPER:-https://github.com/Klipper3d/klipper.git}"
MAINLINE_MOONRAKER="${MAINLINE_MOONRAKER:-https://github.com/Arksine/moonraker.git}"
MAINLINE_KLIPPERSCREEN="${MAINLINE_KLIPPERSCREEN:-https://github.com/KlipperScreen/KlipperScreen.git}"
FREETHINKER_REPO="${FREETHINKER_REPO:-https://github.com/jpapiez/freeThinker.git}"
FREETHINKER_BRANCH="${FREETHINKER_BRANCH:-main}"
KATAPULT_REPO="${KATAPULT_REPO:-https://github.com/Arksine/katapult.git}"
KATAPULT_BRANCH="${KATAPULT_BRANCH:-master}"
KATAPULT_DIR="${KATAPULT_DIR:-$PRINTER_HOME/katapult}"

# Pinned host commits for no-flash compatibility with the stock 2024 MCU
# firmware (mainboard build 20240326, toolhead/EECAN build 20240409).
#
# These pins keep the Klipper/Moonraker HOST in lockstep with firmware the
# script does NOT reflash. Override via env if your firmware differs. If left
# empty, the script falls back to the documented stable tag below and prints a
# loud warning — verify the printer still talks to both MCUs before printing.
KLIPPER_PIN="${KLIPPER_PIN:-}"            # e.g. a 2024-03/04-era commit or v0.12.0
KLIPPER_FALLBACK_TAG="${KLIPPER_FALLBACK_TAG:-v0.12.0}"
MOONRAKER_PIN="${MOONRAKER_PIN:-}"        # e.g. 42357891a3716cd332ef60b28af09f8732dbf67a (live HEAD)
MOONRAKER_FALLBACK_BRANCH="${MOONRAKER_FALLBACK_BRANCH:-master}"

# Known stock-fork URL fragments we migrate away from (case-insensitive).
FORK_KS_PATTERNS="xpp012|everyone3d|gitcode|gitee|eryone"

# Dry-run support: DRY_RUN=1 prints destructive actions without doing them.
DRY_RUN="${DRY_RUN:-0}"

# --- Helpers -----------------------------------------------------------------

info()  { echo "FT_MIGRATE: $*"; }
warn()  { echo "FT_MIGRATE [WARN]: $*" >&2; }
fatal() { echo "FT_MIGRATE [ERROR]: $*" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "FT_MIGRATE [dry-run]: $*"
    else
        "$@"
    fi
}

is_root() { [ "$(id -u 2>/dev/null || echo 1000)" = "0" ]; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a privileged command: directly if root, else via sudo -n, else warn+skip.
priv() {
    if is_root; then
        run "$@"
    elif have sudo && sudo -n true 2>/dev/null; then
        run sudo "$@"
    else
        warn "  Skipped privileged step (need root): $*"
        return 0
    fi
}

# --- Preflight ---------------------------------------------------------------

info "=== freeThinker migration ==="
[ "$DRY_RUN" = "1" ] && info "(DRY RUN — no changes will be made)"
have git || fatal "git not found. Install git and re-run."

[ -d "$PRINTER_HOME" ] || fatal "Printer home '$PRINTER_HOME' not found. Set PRINTER_USER/PRINTER_HOME."
info "Printer user: $PRINTER_USER   home: $PRINTER_HOME"
echo ""

# =============================================================================
# PHASE 1 — ERADICATE ALL PHONE-HOME / CLOUD-RELAY GARBAGE
# =============================================================================
# This runs FIRST and unconditionally. Even if a later phase fails, the cloud
# relay is already dead.

info "[1/6] Removing phone-home / cloud-relay components (farm3d + friends)"

# 1a. Stop, disable, and mask the farm3d systemd unit so it never restarts.
if have systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^farm3d.service'; then
    priv systemctl stop farm3d.service    2>/dev/null || true
    priv systemctl disable farm3d.service 2>/dev/null || true
    priv systemctl mask farm3d.service    2>/dev/null || true
    info "  Stopped/disabled/masked farm3d.service"
fi

# 1b. Kill any running relay / monitor processes.
for proc in "farm3d" "mq.py" "monitor.sh" "phrozen_slave_ota" "phrozen_master" "frpc"; do
    if pgrep -f "$proc" >/dev/null 2>&1; then
        run pkill -f "$proc" 2>/dev/null || true
        info "  Killed processes matching: $proc"
    fi
done

# 1c. Remove the farm3d payload and its bundled gitee KlipperScreen fork.
for d in \
    "$PRINTER_HOME/farm3d" \
    "$KLIPPERSCREEN_DIR/farm3d" \
    "$PRINTER_HOME/KlipperScreen_bk/farm3d"; do
    if [ -e "$d" ]; then
        run rm -rf "$d" && info "  Removed $d"
    fi
done

# 1d. Strip the ip-api.com geo lookup (IP leak) and farm3d/monitor autostart
#     from rc.local variants. Comment rather than delete, for forensics.
for rc in /etc/rc.local "$PRINTER_HOME"/mainsail/all/rc.local "$KLIPPERSCREEN_DIR"/all/rc.local; do
    [ -f "$rc" ] || continue
    if grep -qE 'ip-api\.com|farm3d|mq\.py|monitor\.sh' "$rc" 2>/dev/null; then
        priv sed -i -E '\#(ip-api\.com|farm3d|mq\.py|monitor\.sh)#{ /^[[:space:]]*#/! s/^/# freeThinker disabled: / }' "$rc" 2>/dev/null \
            && info "  Neutralized phone-home lines in $rc"
    fi
done

# 1e. Clean crontab entries referencing the relay.
if have crontab; then
    if crontab -l 2>/dev/null | grep -qE 'farm3d|mq\.py|monitor\.sh|frpc|phrozen'; then
        crontab -l 2>/dev/null | grep -vE 'farm3d|mq\.py|monitor\.sh|frpc|phrozen' | crontab - 2>/dev/null \
            && info "  Cleaned phone-home crontab entries"
    fi
fi

# 1f. Sanity report: anything still talking to the known broker?
if have systemctl && systemctl is-active --quiet farm3d.service 2>/dev/null; then
    warn "  farm3d.service still active — re-run this script with sudo."
else
    info "  Phone-home stack neutralized."
fi
echo ""

# =============================================================================
# PHASE 2 — PRESERVE CUSTOM KLIPPER EXTRAS (klipper is not a git repo on stock)
# =============================================================================

info "[2/6] Backing up custom Klipper extras and live configs"
run mkdir -p "$BACKUP_DIR"
if [ -d "$KLIPPER_DIR/klippy/extras" ]; then
    for f in pressure_sensor.py rc522.py; do
        src="$KLIPPER_DIR/klippy/extras/$f"
        [ -f "$src" ] && run cp -a "$src" "$BACKUP_DIR/" && info "  Saved extras/$f"
    done
fi
# Snapshot the whole live config tree (cheap insurance).
if [ -d "$PRINTER_HOME/printer_data/config" ]; then
    run cp -a "$PRINTER_HOME/printer_data/config" "$BACKUP_DIR/config-snapshot" 2>/dev/null || true
    info "  Snapshotted printer_data/config -> $BACKUP_DIR/config-snapshot"
fi
echo ""

# =============================================================================
# PHASE 3 — KLIPPER HOST -> FRESH MAINLINE CLONE (pinned, no MCU reflash)
# =============================================================================

info "[3/6] Klipper host -> mainline (no-flash pin)"
if [ -d "$KLIPPER_DIR/.git" ]; then
    current_url=$(git -C "$KLIPPER_DIR" remote get-url origin 2>/dev/null || echo "")
    info "  Existing git repo (origin: ${current_url:-none})"
    run git -C "$KLIPPER_DIR" remote set-url origin "$MAINLINE_KLIPPER"
    run git -C "$KLIPPER_DIR" fetch origin --tags --prune 2>/dev/null || warn "  Fetch failed — check network"
else
    info "  ~/klipper is not a git repo (stock hand-edited copy). Replacing with a clean mainline clone."
    if have systemctl; then priv systemctl stop klipper 2>/dev/null || true; fi
    if [ -d "$KLIPPER_DIR" ]; then
        run mv "$KLIPPER_DIR" "$BACKUP_DIR/klipper-stock-handedited" 2>/dev/null || run rm -rf "$KLIPPER_DIR"
        info "  Moved stock ~/klipper to $BACKUP_DIR/klipper-stock-handedited"
    fi
    run git clone "$MAINLINE_KLIPPER" "$KLIPPER_DIR" || fatal "Failed to clone mainline Klipper"
fi

if [ -n "$KLIPPER_PIN" ] && git -C "$KLIPPER_DIR" cat-file -e "$KLIPPER_PIN" 2>/dev/null; then
    run git -C "$KLIPPER_DIR" checkout -q "$KLIPPER_PIN" || warn "  Could not checkout KLIPPER_PIN=$KLIPPER_PIN"
    info "  Pinned Klipper host to $KLIPPER_PIN"
else
    [ -n "$KLIPPER_PIN" ] && warn "  KLIPPER_PIN=$KLIPPER_PIN not found after fetch."
    warn "  Falling back to tag $KLIPPER_FALLBACK_TAG. VERIFY both MCUs connect"
    warn "  before printing — the host must match the un-reflashed 2024 firmware."
    run git -C "$KLIPPER_DIR" checkout -q "$KLIPPER_FALLBACK_TAG" 2>/dev/null \
        || warn "  Fallback tag $KLIPPER_FALLBACK_TAG not found; leaving on default branch."
fi
echo ""

# =============================================================================
# PHASE 4 — MOONRAKER -> PINNED MAINLINE (already arksine remote, but dirty)
# =============================================================================

info "[4/6] Moonraker -> pinned mainline"
if [ -d "$MOONRAKER_DIR/.git" ]; then
    run git -C "$MOONRAKER_DIR" remote set-url origin "$MAINLINE_MOONRAKER"
    run git -C "$MOONRAKER_DIR" fetch origin --tags --prune 2>/dev/null || warn "  Fetch failed — check network"
    if [ -n "$MOONRAKER_PIN" ] && git -C "$MOONRAKER_DIR" cat-file -e "$MOONRAKER_PIN" 2>/dev/null; then
        run git -C "$MOONRAKER_DIR" reset --hard "$MOONRAKER_PIN" && info "  Pinned Moonraker to $MOONRAKER_PIN"
    else
        [ -n "$MOONRAKER_PIN" ] && warn "  MOONRAKER_PIN not found; resetting to origin/$MOONRAKER_FALLBACK_BRANCH"
        run git -C "$MOONRAKER_DIR" checkout -q "$MOONRAKER_FALLBACK_BRANCH" 2>/dev/null || true
        run git -C "$MOONRAKER_DIR" reset --hard "origin/$MOONRAKER_FALLBACK_BRANCH" 2>/dev/null \
            && info "  Reset Moonraker to origin/$MOONRAKER_FALLBACK_BRANCH"
    fi
else
    warn "  ~/moonraker is not a git repo — skipping (install Moonraker via KIAUH/installer)."
fi
echo ""

# =============================================================================
# PHASE 5 — KLIPPERSCREEN FORK -> MAINLINE
# =============================================================================

info "[5/6] KlipperScreen -> mainline"
ks_is_fork=0
if [ -d "$KLIPPERSCREEN_DIR/.git" ]; then
    ks_url=$(git -C "$KLIPPERSCREEN_DIR" remote get-url origin 2>/dev/null || echo "")
    echo "$ks_url" | grep -qiE "$FORK_KS_PATTERNS" && ks_is_fork=1
fi
if [ "$ks_is_fork" = "1" ] || [ ! -d "$KLIPPERSCREEN_DIR/.git" ]; then
    if have systemctl; then priv systemctl stop KlipperScreen 2>/dev/null || true; fi
    if [ -d "$KLIPPERSCREEN_DIR" ]; then
        run mv "$KLIPPERSCREEN_DIR" "$BACKUP_DIR/KlipperScreen-fork" 2>/dev/null || run rm -rf "$KLIPPERSCREEN_DIR"
        info "  Moved fork to $BACKUP_DIR/KlipperScreen-fork"
    fi
    run git clone "$MAINLINE_KLIPPERSCREEN" "$KLIPPERSCREEN_DIR" || warn "  Failed to clone mainline KlipperScreen"
    info "  Cloned mainline KlipperScreen (freeThinker plugin layered by installer)"
else
    info "  KlipperScreen origin not a known fork — leaving as-is."
fi
echo ""

# =============================================================================
# PHASE 6 — UPDATE_MANAGER + HAND OFF TO INSTALLER
# =============================================================================

info "[6/7] freeThinker overlay + update_manager"

# Clone or refresh the freeThinker overlay repo.
if [ -d "$FREETHINKER_DIR/.git" ]; then
    run git -C "$FREETHINKER_DIR" fetch origin --prune 2>/dev/null || warn "  Fetch failed"
    run git -C "$FREETHINKER_DIR" checkout -q "$FREETHINKER_BRANCH" 2>/dev/null || true
    run git -C "$FREETHINKER_DIR" reset --hard "origin/$FREETHINKER_BRANCH" 2>/dev/null || true
else
    run git clone --branch "$FREETHINKER_BRANCH" --single-branch \
        "$FREETHINKER_REPO" "$FREETHINKER_DIR" || fatal "Failed to clone freeThinker overlay"
fi

# Register [update_manager freeThinker] (installer also manages this; harmless if duplicated-guarded).
if [ -f "$MOONRAKER_CONF" ]; then
    if grep -q '\[update_manager freeThinker\]' "$MOONRAKER_CONF" 2>/dev/null; then
        info "  [update_manager freeThinker] already present"
    elif [ "$DRY_RUN" = "1" ]; then
        info "  [dry-run] would append [update_manager freeThinker] to $MOONRAKER_CONF"
    else
        cat >> "$MOONRAKER_CONF" <<FT_EOF

[update_manager freeThinker]
type: git_repo
path: $FREETHINKER_DIR
origin: $FREETHINKER_REPO
primary_branch: $FREETHINKER_BRANCH
managed_services:
  klipper
  moonraker
  KlipperScreen
FT_EOF
        info "  Added [update_manager freeThinker]"
    fi
else
    warn "  $MOONRAKER_CONF not found — installer will create it."
fi

# =============================================================================
# PHASE 7 — CANBOOT -> KATAPULT (LATEST SOURCE CHECKOUT)
# =============================================================================

info "[7/7] Replacing legacy CanBoot checkout with latest Katapult source"

# Remove/migrate common legacy canboot checkout locations to avoid using stale
# sources by accident when building bootloaders.
for legacy in "$PRINTER_HOME/canboot" "$PRINTER_HOME/CanBoot"; do
    [ -e "$legacy" ] || continue
    if [ "$legacy" = "$KATAPULT_DIR" ]; then
        continue
    fi
    bn=$(basename "$legacy")
    dst="$BACKUP_DIR/${bn}-legacy"
    run rm -rf "$dst"
    run mv "$legacy" "$dst"
    info "  Moved legacy $legacy -> $dst"
done

# Ensure a fresh Katapult checkout from upstream is present for bootloader
# builds and flashing tools.
if [ -d "$KATAPULT_DIR/.git" ]; then
    run git -C "$KATAPULT_DIR" remote set-url origin "$KATAPULT_REPO"
    run git -C "$KATAPULT_DIR" fetch origin --tags --prune 2>/dev/null || fatal "Failed to fetch Katapult from $KATAPULT_REPO"
    run git -C "$KATAPULT_DIR" checkout -q "$KATAPULT_BRANCH" 2>/dev/null || fatal "Failed to checkout Katapult branch $KATAPULT_BRANCH"
    run git -C "$KATAPULT_DIR" reset --hard "origin/$KATAPULT_BRANCH" 2>/dev/null || fatal "Failed to reset Katapult to origin/$KATAPULT_BRANCH"
    info "  Updated Katapult checkout at $KATAPULT_DIR"
else
    [ -d "$KATAPULT_DIR" ] && run rm -rf "$KATAPULT_DIR"
    run git clone --branch "$KATAPULT_BRANCH" --single-branch \
        "$KATAPULT_REPO" "$KATAPULT_DIR" || fatal "Failed to clone Katapult from $KATAPULT_REPO"
    info "  Cloned Katapult to $KATAPULT_DIR"
fi

[ -f "$KATAPULT_DIR/scripts/flashtool.py" ] || fatal "Katapult flashtool missing at $KATAPULT_DIR/scripts/flashtool.py"

# Compatibility symlink for older instructions/scripts that still reference
# ~/canboot as a path.
if [ "$KATAPULT_DIR" != "$PRINTER_HOME/canboot" ]; then
    run ln -sfn "$KATAPULT_DIR" "$PRINTER_HOME/canboot"
    info "  Symlinked $PRINTER_HOME/canboot -> $KATAPULT_DIR"
fi

# Hand off to the freeThinker installer (deploys configs, extras, KS plugin).
INSTALLER="$FREETHINKER_DIR/install.sh"
if [ -f "$INSTALLER" ]; then
    info "  Handing off to freeThinker installer."
    info "  Run, picking your hotend:"
    info "    cd $FREETHINKER_DIR && ./install.sh --variant x400_300 --hotend 300"
    info "    (or --variant x400_350 --hotend 350)"
else
    warn "  Installer not found at $INSTALLER (clone may have failed)."
fi

echo ""
info "=== Migration phases complete ==="
info "Pre-migration backups: $BACKUP_DIR"
info "NEXT: run the installer above, then restart Klipper and confirm BOTH MCUs"
info "connect (Loaded MCU 'mcu' and 'EECAN' in klippy.log) before printing."
info "MCU/toolhead reflashing remains OPTIONAL — see scripts/mcu/."
