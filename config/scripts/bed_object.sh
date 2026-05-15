#!/usr/bin/env bash
set -euo pipefail

cv_script="{{PRINTER_HOME}}/mainsail/all/cv.py"

if [[ ! -f "$cv_script" ]]; then
  echo "[thinker-x400] bed_object hook skipped: missing $cv_script" >&2
  exit 0
fi

exec python3 "$cv_script" 32
