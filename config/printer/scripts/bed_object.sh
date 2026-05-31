#!/usr/bin/env bash

# File: config/printer/scripts/bed_object.sh
# Purpose: Capture and process bed image data for object detection hooks.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cv_script="${script_dir}/cv.py"

if [[ ! -f "$cv_script" ]]; then
  echo "[thinker-x400] bed_object hook skipped: missing $cv_script" >&2
  exit 0
fi

if ! python3 -c 'import cv2, numpy' >/dev/null 2>&1; then
  echo "[thinker-x400] bed_object hook skipped: missing python modules cv2/numpy" >&2
  exit 0
fi

exec python3 "$cv_script" 32
