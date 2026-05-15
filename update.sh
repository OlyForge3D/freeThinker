#!/usr/bin/env bash
# Pulls the latest thinker-x400 sources and re-runs the installer. Stub.
set -euo pipefail

cd "$(dirname "$0")"
git pull --ff-only
exec ./install.sh "$@"
