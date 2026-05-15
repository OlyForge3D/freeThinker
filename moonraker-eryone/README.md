# moonraker-eryone

Moonraker components (`moonraker/components/eryone_*.py`) that add Thinker
X400 functionality without modifying upstream Moonraker sources.

License: **GPL-3.0** (matches upstream Moonraker).

## Layout

```
moonraker-eryone/
├── components/     # moonraker/components modules, installed via symlink
└── docs/
    └── upstream_diff.md
```

## Included in this phase

- `components/eryone_file_manager.py`
  - Replaces the legacy hard-coded upload temp path patch with a
    runtime-configurable overlay (`upload_tmp_root`).
- `components/eryone_metadata.py`
  - Keeps upstream metadata parsing and adds optional extraction of
    `; ERYONE_*=` comment hints into `metadata["eryone_hints"]`.

## Example Moonraker config

```ini
[eryone_file_manager]
# Optional; defaults to ~/printer_data/gcodes
upload_tmp_root: ~/printer_data/gcodes

[eryone_metadata]
# Optional bytes to scan from gcode header for ERYONE_ hints
hint_scan_bytes: 1048576
```
