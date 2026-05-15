# klipperscreen-eryone

KlipperScreen drop-in panels and overrides for the Thinker X400.

License: **AGPL-3.0** (matches upstream KlipperScreen). See
[`LICENSE`](LICENSE).

## Layout

```
klipperscreen-eryone/
├── panels/          # additional panel modules, installed via symlink
├── overrides/       # opt-in replacements for upstream panels
├── ks_includes/     # shared widgets (e.g. bedmap extension)
├── locales/         # .po translations; .mo built at install time
└── scripts/
    └── build_locales.sh
```

## Conventions

- Panel modules are prefixed `eryone_` to avoid clashes with upstream
  panels.
- Behavioral changes to upstream panels (`extrude.py`, `print.py`, etc.)
  are split into:
  - bug fixes → upstream PRs;
  - X400-only UI → new panels referenced from menu config.

## Status

Empty scaffold. Phase 4 ports `statis.py`, `tuning_settings_panel.py`, the
RFID-aware filament change panel, and the bedmap extension.
