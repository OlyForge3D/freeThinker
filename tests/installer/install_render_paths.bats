#!/usr/bin/env bats

@test "installer steps render user-relative paths and variant firmware" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/../.."

    export REPO_ROOT="$PWD"
    tmp_root="$(mktemp -d)"
    export PRINTER_USER="testuser"
    export PRINTER_HOME="${tmp_root}/home/${PRINTER_USER}"
    export PRINTER_DATA_DIR="${PRINTER_HOME}/printer_data"
    export CONFIG_DIR="${PRINTER_DATA_DIR}/config"
    export KLIPPER_DIR="${PRINTER_HOME}/klipper"
    export MOONRAKER_DIR="${PRINTER_HOME}/moonraker"
    export KLIPPERSCREEN_DIR="${PRINTER_HOME}/KlipperScreen"

    mkdir -p \
      "${KLIPPER_DIR}/klippy/extras" \
      "${MOONRAKER_DIR}/moonraker/components" \
      "${KLIPPERSCREEN_DIR}/panels" \
      "${CONFIG_DIR}"

    # shellcheck disable=SC1091
    source installer/lib/common.sh
    # shellcheck disable=SC1091
    source installer/variants/x400_350.env
    export VARIANT_ID EECAN_INCLUDE PRESSURE_SENSOR_FIRMWARE

    # shellcheck disable=SC1091
    source installer/steps/20_klipper_extras.sh
    # shellcheck disable=SC1091
    source installer/steps/30_moonraker_components.sh
    # shellcheck disable=SC1091
    source installer/steps/40_klipperscreen_plugin.sh
    # shellcheck disable=SC1091
    source installer/steps/50_configs.sh
    # shellcheck disable=SC1091
    source installer/steps/70_firmware_assets.sh

    test -L "${KLIPPER_DIR}/klippy/extras/eryone_plr.py"
    test -L "${MOONRAKER_DIR}/moonraker/components/eryone_metadata.py"
    test ! -e "${MOONRAKER_DIR}/moonraker/components/eryone_file_manager.py"
    test -L "${KLIPPERSCREEN_DIR}/panels/eryone_statis.py"
    test -f "${CONFIG_DIR}/printer.cfg"
    test -f "${CONFIG_DIR}/x400.cfg"
    test -f "${CONFIG_DIR}/scripts/bed_object.sh"
    test -f "${CONFIG_DIR}/firmware/thinker-x400/stm32_pressure_sensor_350.hex"

    grep -q "path: ${PRINTER_DATA_DIR}/gcodes" "${CONFIG_DIR}/mainsail.cfg"
    grep -q "command: ${CONFIG_DIR}/plr.sh" "${CONFIG_DIR}/x400.cfg"
    grep -q "command: ${CONFIG_DIR}/scripts/bed_object.sh" "${CONFIG_DIR}/x400.cfg"
    grep -q "^\\[include plr.cfg\\]$" "${CONFIG_DIR}/printer.cfg"
    ! grep -q "^\\[eryone_file_manager\\]$" "${CONFIG_DIR}/moonraker.thinker-x400.conf"
  '
  [ "$status" -eq 0 ]
}
