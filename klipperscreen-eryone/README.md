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

Phase 4 bootstrap imported legacy panel sources as namespaced overlays:

- `panels/eryone_statis.py`
- `panels/eryone_tuning_settings_panel.py`
- `panels/eryone_chgfilament.py`

Hard-coded `/home/mks/...` paths were replaced with user-home-relative
resolution where applicable.
