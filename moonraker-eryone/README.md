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

- `components/eryone_metadata.py`
  - Keeps upstream metadata parsing and adds optional extraction of
    `; ERYONE_*=` comment hints into `metadata["eryone_hints"]`.
- No `machine.py` overlay is shipped; legacy machine-level drift was analyzed
  and intentionally not carried into the pluginized migration.
- Stock Moonraker upload temp-path behavior is used (no file-manager overlay).

## Example Moonraker config

```ini
[eryone_metadata]
# Optional bytes to scan from gcode header for ERYONE_ hints
hint_scan_bytes: 1048576
```
