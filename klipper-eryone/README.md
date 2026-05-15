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

## Status

Empty scaffold. Phase 1 (`docs/upstream_diff.md`) and Phase 2 (porting
`rc522.py`, etc.) populate this directory.
