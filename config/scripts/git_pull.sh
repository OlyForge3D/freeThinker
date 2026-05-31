#!/usr/bin/env bash

# File: config/scripts/git_pull.sh
# Purpose: Safely update the freeThinker checkout from git.
#
set -euo pipefail

updater="{{REPO_ROOT}}/update.sh"

if [[ ! -x "$updater" ]]; then
  echo "[thinker-x400] update helper not found at $updater" >&2
  exit 1
fi

exec "$updater"
