#!/usr/bin/env sh
set -eu

mode="${1:-}"
printer_cfg="${PRINTER_CFG:-$HOME/printer_data/config/printer.cfg}"

case "$mode" in
  300)
    target_cfg="EECAN1_300.cfg"
    ;;
  350)
    target_cfg="EECAN1_350.cfg"
    ;;
  *)
    echo "ERROR: Usage: legacy_set_hotend.sh <300|350>"
    exit 1
    ;;
esac

if [ ! -f "$printer_cfg" ]; then
  echo "ERROR: Missing printer config: $printer_cfg"
  exit 1
fi

for old_cfg in EECAN.cfg EECAN1.cfg EECAN1_300.cfg EECAN1_350.cfg; do
  if [ "$old_cfg" != "$target_cfg" ]; then
    sed -i.bak "s/$old_cfg/$target_cfg/g" "$printer_cfg"
  fi
done

rm -f "$printer_cfg.bak"
echo "Updated include target to $target_cfg in $printer_cfg"
