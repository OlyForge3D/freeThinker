#!/usr/bin/env bash

# File: scripts/mcu/build_katapult_bootloaders.sh
# Purpose: Build Katapult bootloader binaries from imported X400 profiles.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KATAPULT_DIR="${KATAPULT_DIR:-$HOME/katapult}"
PROFILE_DIR="${PROFILE_DIR:-$REPO_ROOT/config/mcu-bootloader-configurations}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/out/bootloader}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

MAINBOARD_PROFILE="${MAINBOARD_PROFILE:-$PROFILE_DIR/stm32f407_katapult_bootloader.config}"
TOOLHEAD_PROFILE="${TOOLHEAD_PROFILE:-$PROFILE_DIR/rp2040_katapult_Bootloader_usb.config}"

usage() {
  cat <<'EOF'
Usage: ./scripts/mcu/build_katapult_bootloaders.sh [options]

Options:
  --katapult-dir <path>     Path to Katapult checkout (default: ~/katapult)
  --profile-dir <path>      Directory containing bootloader profile configs
  --output-dir <path>       Output directory for generated bootloader binaries
  --jobs <n>                Parallel build jobs
  -h, --help                Show this help

Environment overrides:
  MAINBOARD_PROFILE, TOOLHEAD_PROFILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --katapult-dir)
      KATAPULT_DIR="$2"
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

[[ -d "$KATAPULT_DIR" ]] || { echo "Missing Katapult dir: $KATAPULT_DIR" >&2; exit 1; }
[[ -f "$MAINBOARD_PROFILE" ]] || { echo "Missing mainboard profile: $MAINBOARD_PROFILE" >&2; exit 1; }
[[ -f "$TOOLHEAD_PROFILE" ]] || { echo "Missing toolhead profile: $TOOLHEAD_PROFILE" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"

build_one() {
  local role="$1"
  local profile="$2"

  echo "[$role] Building with profile: $profile"
  cp "$profile" "$KATAPULT_DIR/.config"

  make -C "$KATAPULT_DIR" olddefconfig
  make -C "$KATAPULT_DIR" clean
  make -C "$KATAPULT_DIR" -j"$JOBS"

  case "$role" in
    mainboard)
      [[ -f "$KATAPULT_DIR/out/deployer.bin" ]] || { echo "[$role] Missing out/deployer.bin" >&2; exit 1; }
      cp "$KATAPULT_DIR/out/deployer.bin" "$OUTPUT_DIR/katapult_mainboard_stm32f407.bin"
      ;;
    toolhead)
      [[ -f "$KATAPULT_DIR/out/deployer.bin" ]] || { echo "[$role] Missing out/deployer.bin" >&2; exit 1; }
      cp "$KATAPULT_DIR/out/deployer.bin" "$OUTPUT_DIR/katapult_toolhead_rp2040.bin"
      if [[ -f "$KATAPULT_DIR/out/deployer.uf2" ]]; then
        cp "$KATAPULT_DIR/out/deployer.uf2" "$OUTPUT_DIR/katapult_toolhead_rp2040.uf2"
      fi
      ;;
  esac
}

build_one "mainboard" "$MAINBOARD_PROFILE"
build_one "toolhead" "$TOOLHEAD_PROFILE"

echo "Bootloader build complete. Output directory: $OUTPUT_DIR"
