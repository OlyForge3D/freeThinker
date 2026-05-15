# KlipperScreen upstream diff inventory

This document inventories Eryone-specific KlipperScreen changes extracted from
the legacy `thinker400_klipperscreen` repo and maps them to migration
categories.

## Baseline provenance

- **Legacy root import commit:** `1ba5fc27d2691074a0147a914b792d107ab056fe` (`x400`, 2025-06-02)
- **Upstream repo:** `KlipperScreen/KlipperScreen`
- **Baseline SHA used for comparison:** `2397a44` (2025-05-25)
- **Method:** date-based baseline + blob-hash comparison on runtime paths
  (`panels/`, `ks_includes/`, `screen.py`, `scripts/`, `styles/`).

## Snapshot-level comparison (legacy root vs upstream baseline)

| same | modified | added | missing |
|------|----------|-------|---------|
| 345  | 151      | 26    | 189     |

The vendored snapshot heavily diverges from upstream (including removals of
newer upstream files). We will not port this wholesale; we will port only X400
features.

## Net custom delta after the legacy root import

`git diff 1ba5fc2..HEAD` for KlipperScreen surfaces:

- **64 modified files**
- **6 added files**

Added files in net delta:

1. `panels/statis.py`
2. `panels/tuning_settings_panel.py`
3. `ks_includes/locales/zh_CN/LC_MESSAGES/compile_copy.bat`
4. `styles/material-light/images2/visibility.png`
5. `styles/material-light/images2/visibility_off.png`
6. `styles/z-bolt/images/reloadUI.svg`

Largest modified files:

- `panels/extrude.py` (`+914 / -68`)
- `panels/print.py` (`+927 / -12`)
- `panels/bed_mesh.py` (`+548 / -23`)
- `screen.py` (`+147 / -6`)
- `ks_includes/widgets/bedmap.py` (`+92 / -11`)

## A/B/C/D inventory

| Legacy path(s) | Category | Evidence | Planned disposition |
|----------------|----------|----------|---------------------|
| `panels/statis.py`, `panels/tuning_settings_panel.py` | **A** | Net-new panel modules | Port as `klipperscreen-eryone/panels/eryone_statis.py` and `eryone_tuning_settings.py`; add menu wiring via installer. |
| `panels/chgfilament.py` (legacy-added vs upstream baseline) | **A/B** | Added in root snapshot and subsequently modified | Split RFID-specific flow into `eryone_chgfilament.py`; avoid replacing upstream panel wholesale. |
| `ks_includes/locales/zh_CN/.../compile_copy.bat` | **D** | Windows helper for manual locale compilation | Drop from Linux-targeted overlay; build `.mo` during install via `msgfmt`. |
| `styles/.../visibility*.png`, `styles/z-bolt/images/reloadUI.svg` | **A** | UI assets added in net delta | Keep as plugin assets if referenced by Eryone panels; otherwise drop. |
| `panels/extrude.py`, `panels/print.py`, `panels/bed_mesh.py`, `screen.py`, `ks_includes/widgets/bedmap.py` | **B** | High-churn behavioral edits in core upstream panels | Decompose into focused Eryone overlays/new panels. Upstream bug fixes should be submitted upstream and not retained as private patch stack. |
| Locale `.po/.mo` updates in `ks_includes/locales/*` | **C** | Translation and message catalog updates | Keep `.po` sources in plugin repo; regenerate `.mo` at install/build time. |
| Missing upstream files (spoolman, updater, notification panels, additional locales/stats) | **D** | 189 files missing at snapshot level | Treat as stale vendored drift; do not mirror removals in the new overlay. |

## Notes for Phase 4

- Plugin payload should be narrowed to explicit Eryone panels/features; avoid
  carrying broad forks of upstream `extrude.py` and `print.py`.
- Any feature requiring upstream panel replacement should be made opt-in and
  version-gated.
