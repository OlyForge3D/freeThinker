#!/usr/bin/env bash

# File: update.sh
# Purpose: Fast-forward repo and re-run installer with provided arguments.
#
set -euo pipefail

cd "$(dirname "$0")"
git pull --ff-only
exec ./install.sh "$@"
