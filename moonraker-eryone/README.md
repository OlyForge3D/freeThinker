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

## Status

Empty scaffold. Phase 3 implements `eryone_metadata.py` (replacing the
current `metadata.py` rewrite by subclassing the upstream `MetadataExtractor`)
and decides the fate of the 1-line `file_manager.py` change.
