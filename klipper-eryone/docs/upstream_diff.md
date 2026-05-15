# Klipper upstream diff inventory

This document inventories Eryone-specific Klipper changes extracted from the
legacy `thinker400_klipperscreen` repo and maps them to migration categories.

## Baseline provenance

- **Legacy root import commit:** `1ba5fc27d2691074a0147a914b792d107ab056fe` (`x400`, 2025-06-02)
- **Upstream repo:** `Klipper3d/klipper`
- **Baseline SHA used for comparison:** `cfa48fe3` (2025-05-31)
- **Method:** select the latest upstream commit before the legacy root-import
  timestamp, then compare blob hashes for runtime paths (`klippy/`, `src/`,
  `config/`, `scripts/`). See `docs/upstream_baselines.md`.

## Snapshot-level comparison (legacy root vs upstream baseline)

Focused runtime paths only:

| same | modified | added | missing |
|------|----------|-------|---------|
| 479  | 231      | 7     | 44      |

The legacy snapshot diverges broadly from upstream due to vendoring and
partial-tree drift. Migration will not port that whole delta; it will port the
X400-specific behavior only.

## Net custom delta after the legacy root import

`git diff 1ba5fc2..HEAD -- klipper/` contains only six net file deltas:

1. `klipper/klippy/extras/rc522.py` (new file)
2. `klipper/klippy/extras/bed_mesh.py` (2-line behavioral patch)
3. `klipper/klippy/extras/verify_heater.py` (2-line behavioral patch)
4. `klipper/klippy/extras/virtual_sdcard.py` (+30 lines, PLR/resume hooks)
5. `klipper/klippy/queuelogger.py` (backupCount tuning)
6. `klipper/src/pressure_sensor.c` (deleted from current head; existed in root
   and intermediate commits)

## A/B/C/D inventory

| Legacy path | Category | Evidence | Planned disposition |
|-------------|----------|----------|---------------------|
| `klipper/klippy/extras/rc522.py` | **A** | New module (+474 lines) in net delta | Port to `klipper-eryone/extras/eryone_rc522.py`, rename config sections, keep host logic out of core Klipper. |
| `klipper/klippy/extras/pressure_sensor.py` | **A** | Present in root snapshot as legacy-only add vs upstream | Re-evaluate against current Klipper APIs; if still required, port as `eryone_pressure_sensor.py` or fold into firmware-side interface docs. |
| `klipper/src/pressure_sensor.c` | **A/B** | Added in root snapshot, later removed from current legacy head | Keep source under `firmware-src/`; prefer out-of-tree firmware patch series with pinned Klipper SHAs; upstream PR is optional stretch goal. |
| `klipper/klippy/extras/bed_mesh.py` | **B** | `probe_count` minimum changed from 3 to 2 | Re-implement as an X400-specific wrapper/validator (or config-level override) instead of patching upstream file. |
| `klipper/klippy/extras/verify_heater.py` | **B** | Chamber heater diagnostic logging path commented out | Replace with explicit, configurable logging policy in an Eryone extra; avoid upstream file patching. |
| `klipper/klippy/extras/virtual_sdcard.py` | **B** | Adds `/tmp/pose` seek + `/tmp/plr.gcode` replay for PLR resume | Re-implement as `eryone_plr` object and gcode hooks, not by editing upstream `virtual_sdcard.py`. |
| `klipper/klippy/queuelogger.py` | **B** | `backupCount` changed 5 → 1 | Move to runtime logrotate/system config; do not carry source patch. |
| `klipper/klippy/chelper/c_helper.so` | **D** | Binary artifact in legacy tree | Drop; never ship built artifacts in source repo. |
| Remaining broad snapshot drift in `klippy/`, `src/`, `scripts/` | **D** | 231 modified + 44 missing files at snapshot level | Treat as upstream version drift, not X400 feature work. Rebase on upstream and port only categorized A/B behaviors. |

## Notes for Phase 2

- The minimum viable Klipper plugin payload is: `eryone_rc522`, PLR hooks,
  and any pressure-sensor support required by the selected toolhead board.
- No direct edits to upstream `klippy/extras/*.py` should survive into the new
  repo.

## Phase 2 implementation status

- ✅ `extras/eryone_rc522.py` implemented.
- ✅ Fallback patch queue added under `klipper-eryone/patches/`.
- ✅ Pressure-sensor path decided as out-of-tree firmware source + manifest.
- ⏳ `virtual_sdcard` PLR behavior remains patch-based until replaced by a
  dedicated extra.
