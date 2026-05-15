# klipper-eryone

Klipper extras (`klippy/extras/eryone_*.py`) and prebuilt MCU firmware that
add Thinker X400 functionality without modifying upstream Klipper sources.

License: **GPL-3.0** (matches upstream Klipper).

## Layout

```
klipper-eryone/
├── extras/         # klippy/extras modules, installed via symlink
├── firmware/       # prebuilt .hex/.bin with checksum manifest
├── firmware-src/   # source for MCU additions (e.g. pressure_sensor.c)
├── patches/        # quilt-style upstream patches (only when unavoidable)
└── docs/
    └── upstream_diff.md   # categorization of every Eryone hunk
```

## Adding a new extra

1. Drop the module in `extras/` named `eryone_<feature>.py`.
2. Use a namespaced config section: `[eryone_<feature> ...]`.
3. The installer will symlink it into `<klipper>/klippy/extras/`.

## Included in this phase

- `extras/eryone_rc522.py` — out-of-tree RFID reader integration, extracted
  from legacy `rc522.py`.
- `extras/eryone_plr.py` — out-of-tree power-loss resume wrapper for
  `SDCARD_PRINT_FILE`, replacing the legacy `virtual_sdcard.py` patch.
- `patches/` — intentionally empty by default; reserved for exceptional,
  version-pinned upstream hotfixes.
- `firmware/MANIFEST.json` + `firmware-src/` — pressure-sensor source and
  firmware artifacts with checksums (out-of-tree decision).

## Example config

```ini
[eryone_rc522]
address: 40
speed: 100000
moonraker_host: 127.0.0.1
moonraker_port: 7125
scan_timeout: 5.0
```

GCode command:

- `M410 EXTRUDER=<n> SAVE=<0|1>` — scan RFID tag and optionally store parsed
  material metadata in Moonraker's database namespace `rfid_tags`.
