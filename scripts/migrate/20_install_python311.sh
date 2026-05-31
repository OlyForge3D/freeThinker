#!/bin/sh

# File: scripts/migrate/20_install_python311.sh
# Purpose: Install Python 3.11 and venv tooling required by migration scripts.
#
# freeThinker migration — install a modern Python (3.11) via pyenv for the
# Moonraker and KlipperScreen virtualenvs, WITHOUT touching the system Python
# that Armbian/Debian depend on.
#
# Why: the stock X400 runs Armbian Buster (Debian 10) with Python 3.7.3, which
# is EOL. Current Moonraker needs >= 3.8 and recent KlipperScreen wants >= 3.9.
# Rather than pinning everything to old releases, this builds 3.11 alongside the
# system interpreter under the printer user's home and rebuilds the affected
# virtualenvs against it. Klipper's host runs fine on 3.7 and is left alone.
#
# Run ON THE PRINTER (after 10_migrate_to_freethinker.sh):
#   sh scripts/migrate/20_install_python311.sh
#
# Idempotent. Re-running re-uses an existing pyenv/Python build and only rebuilds
# venvs that are not already on the target version. POSIX sh compatible.

set -eu

# --- Configuration -----------------------------------------------------------

PRINTER_USER="${PRINTER_USER:-mks}"
PRINTER_HOME="${PRINTER_HOME:-/home/$PRINTER_USER}"

PY_VERSION="${PY_VERSION:-3.11.9}"
PYENV_ROOT="${PYENV_ROOT:-$PRINTER_HOME/.pyenv}"

MOONRAKER_DIR="${MOONRAKER_DIR:-$PRINTER_HOME/moonraker}"
MOONRAKER_ENV="${MOONRAKER_ENV:-$PRINTER_HOME/moonraker-env}"
MOONRAKER_REQS="${MOONRAKER_REQS:-$MOONRAKER_DIR/scripts/moonraker-requirements.txt}"

KLIPPERSCREEN_DIR="${KLIPPERSCREEN_DIR:-$PRINTER_HOME/KlipperScreen}"
KLIPPERSCREEN_ENV="${KLIPPERSCREEN_ENV:-$PRINTER_HOME/.KlipperScreen-env}"
KLIPPERSCREEN_REQS="${KLIPPERSCREEN_REQS:-$KLIPPERSCREEN_DIR/scripts/KlipperScreen-requirements.txt}"

# Rebuild these services' venvs. Set to 0 to skip one.
DO_MOONRAKER="${DO_MOONRAKER:-1}"
DO_KLIPPERSCREEN="${DO_KLIPPERSCREEN:-1}"

DRY_RUN="${DRY_RUN:-0}"

# Build dependencies needed to compile CPython on Armbian Buster (aarch64).
BUILD_DEPS="make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils \
tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git"

# --- Helpers -----------------------------------------------------------------

info()  { echo "FT_PY: $*"; }
warn()  { echo "FT_PY [WARN]: $*" >&2; }
fatal() { echo "FT_PY [ERROR]: $*" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "FT_PY [dry-run]: $*"
    else
        "$@"
    fi
}

is_root() { [ "$(id -u 2>/dev/null || echo 1000)" = "0" ]; }
have() { command -v "$1" >/dev/null 2>&1; }

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

# Run a command as the printer user (so pyenv lives in their home, not root's).
as_user() {
    if [ "$(id -un 2>/dev/null)" = "$PRINTER_USER" ]; then
        run env HOME="$PRINTER_HOME" PYENV_ROOT="$PYENV_ROOT" "$@"
    elif have sudo; then
        run sudo -H -u "$PRINTER_USER" env PYENV_ROOT="$PYENV_ROOT" "$@"
    else
        run env HOME="$PRINTER_HOME" PYENV_ROOT="$PYENV_ROOT" "$@"
    fi
}

PYENV_BIN="$PYENV_ROOT/bin/pyenv"
PY_PREFIX="$PYENV_ROOT/versions/$PY_VERSION"
PY_BIN="$PY_PREFIX/bin/python3"

# --- Preflight ---------------------------------------------------------------

info "=== freeThinker: install Python $PY_VERSION via pyenv ==="
[ "$DRY_RUN" = "1" ] && info "(DRY RUN — no changes will be made)"
[ -d "$PRINTER_HOME" ] || fatal "Printer home '$PRINTER_HOME' not found."
info "Printer user: $PRINTER_USER   home: $PRINTER_HOME   target: Python $PY_VERSION"
echo ""

# =============================================================================
# 1 — Build dependencies
# =============================================================================
info "[1/4] Installing CPython build dependencies (apt)"
if have apt-get; then
    priv apt-get update -qq || warn "  apt-get update failed (continuing)"
    # shellcheck disable=SC2086
    priv apt-get install -y $BUILD_DEPS || warn "  Some build deps failed to install"
else
    warn "  apt-get not found; ensure CPython build deps are present manually."
fi
echo ""

# =============================================================================
# 2 — Install pyenv
# =============================================================================
info "[2/4] Installing pyenv into $PYENV_ROOT"
if [ -x "$PYENV_BIN" ]; then
    info "  pyenv already present; skipping clone."
else
    if have git; then
        as_user git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
        info "  Cloned pyenv."
    else
        fatal "git not found; cannot install pyenv."
    fi
fi

# Add pyenv to the printer user's shell rc (idempotent).
PROFILE="$PRINTER_HOME/.profile"
if [ "$DRY_RUN" = "1" ]; then
    info "  [dry-run] would ensure pyenv init lines in $PROFILE"
elif [ -f "$PROFILE" ] && grep -q 'PYENV_ROOT' "$PROFILE" 2>/dev/null; then
    info "  pyenv init already in $PROFILE"
else
    {
        echo ''
        echo '# freeThinker: pyenv'
        echo "export PYENV_ROOT=\"$PYENV_ROOT\""
        # These two lines are written verbatim into .profile for later shell
        # expansion, so they must stay single-quoted here.
        # shellcheck disable=SC2016
        echo 'command -v pyenv >/dev/null 2>&1 || export PATH="$PYENV_ROOT/bin:$PATH"'
        # shellcheck disable=SC2016
        echo 'eval "$(pyenv init -)"'
    } >> "$PROFILE"
    info "  Appended pyenv init to $PROFILE"
fi
echo ""

# =============================================================================
# 3 — Build Python (this is the slow part on the rockchip64 SoC)
# =============================================================================
info "[3/4] Building Python $PY_VERSION (this can take a while on aarch64)"
if [ -x "$PY_BIN" ]; then
    info "  Python $PY_VERSION already built at $PY_PREFIX; skipping."
else
    # MAKE_OPTS parallelism: use available cores but leave one free.
    NPROC="$(nproc 2>/dev/null || echo 2)"
    JOBS=$(( NPROC > 1 ? NPROC - 1 : 1 ))
    as_user env MAKE_OPTS="-j$JOBS" "$PYENV_BIN" install -s "$PY_VERSION" \
        || fatal "Python build failed. Check build deps and free disk/RAM."
    info "  Built Python $PY_VERSION."
fi
echo ""

# =============================================================================
# 4 — Rebuild service virtualenvs against the new interpreter
# =============================================================================
info "[4/4] Rebuilding service virtualenvs on Python $PY_VERSION"

rebuild_venv() {
    name="$1"; venv="$2"; reqs="$3"
    info "  [$name] target venv: $venv"

    if [ ! -f "$reqs" ]; then
        warn "  [$name] requirements not found at $reqs — skipping."
        return 0
    fi

    # If the venv already runs the target version, skip (idempotent).
    if [ -x "$venv/bin/python" ]; then
        cur="$("$venv/bin/python" -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])' 2>/dev/null || echo unknown)"
        if [ "$cur" = "$PY_VERSION" ]; then
            info "  [$name] already on Python $PY_VERSION; skipping."
            return 0
        fi
        info "  [$name] currently Python $cur; rebuilding."
        run mv "$venv" "$venv.pre-py$PY_VERSION.$(date +%Y%m%d%H%M%S)"
    fi

    as_user "$PY_BIN" -m venv "$venv"
    as_user "$venv/bin/python" -m pip install --upgrade pip setuptools wheel
    as_user "$venv/bin/pip" install -r "$reqs"
    info "  [$name] venv rebuilt on Python $PY_VERSION."
}

if [ "$DO_MOONRAKER" = "1" ]; then
    rebuild_venv "moonraker" "$MOONRAKER_ENV" "$MOONRAKER_REQS"
fi
if [ "$DO_KLIPPERSCREEN" = "1" ]; then
    rebuild_venv "KlipperScreen" "$KLIPPERSCREEN_ENV" "$KLIPPERSCREEN_REQS"
fi
echo ""

info "=== Python $PY_VERSION install complete ==="
info "Klipper host is left on system Python (3.7 is fine for klippy)."
info "Restart services to pick up the new venvs:"
info "  sudo systemctl restart moonraker KlipperScreen"
