#!/usr/bin/env bash

# File: scripts/mcu/build_klipper_mcus.sh
# Purpose: Build Klipper firmware binaries for mainboard and toolhead MCUs.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
PROFILE_DIR="${PROFILE_DIR:-$REPO_ROOT/config/support/mcu/mcu-firmware-configurations}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/out/mcu}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

MAINBOARD_PROFILE="${MAINBOARD_PROFILE:-$PROFILE_DIR/stm32f407_klipper_firmware.config}"
TOOLHEAD_PROFILE="${TOOLHEAD_PROFILE:-$PROFILE_DIR/rp2040_klipper_firmware.config}"

usage() {
  cat <<'EOF'
Usage: ./scripts/mcu/build_klipper_mcus.sh [options]

Options:
  --klipper-dir <path>      Path to mainline Klipper checkout (default: ~/klipper)
  --profile-dir <path>      Directory containing MCU profile configs
  --output-dir <path>       Output directory for generated binaries
  --jobs <n>                Parallel build jobs
  -h, --help                Show this help

Environment overrides:
  MAINBOARD_PROFILE, TOOLHEAD_PROFILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --klipper-dir)
      KLIPPER_DIR="$2"
      shift 2
      ;;
    --profile-dir)
      PROFILE_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --jobs)
      JOBS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

[[ -d "$KLIPPER_DIR" ]] || { echo "Missing Klipper dir: $KLIPPER_DIR" >&2; exit 1; }
[[ -f "$MAINBOARD_PROFILE" ]] || { echo "Missing mainboard profile: $MAINBOARD_PROFILE" >&2; exit 1; }
[[ -f "$TOOLHEAD_PROFILE" ]] || { echo "Missing toolhead profile: $TOOLHEAD_PROFILE" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"

build_one() {
  local role="$1"
  local profile="$2"
  local out_bin="$OUTPUT_DIR/klipper_${role}.bin"

  echo "[$role] Building with profile: $profile"
  cp "$profile" "$KLIPPER_DIR/.config"

  make -C "$KLIPPER_DIR" olddefconfig
  make -C "$KLIPPER_DIR" clean
  make -C "$KLIPPER_DIR" -j"$JOBS"

  [[ -f "$KLIPPER_DIR/out/klipper.bin" ]] || {
    echo "[$role] Build succeeded but out/klipper.bin not found" >&2
    exit 1
  }

  cp "$KLIPPER_DIR/out/klipper.bin" "$out_bin"
  echo "[$role] Wrote $out_bin"
}

build_one "mainboard" "$MAINBOARD_PROFILE"
build_one "toolhead" "$TOOLHEAD_PROFILE"

echo "Build complete. Output directory: $OUTPUT_DIR"
