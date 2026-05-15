#!/usr/bin/env bash
set -euo pipefail

updater="{{REPO_ROOT}}/update.sh"

if [[ ! -x "$updater" ]]; then
  echo "[thinker-x400] update helper not found at $updater" >&2
  exit 1
fi

exec "$updater"
