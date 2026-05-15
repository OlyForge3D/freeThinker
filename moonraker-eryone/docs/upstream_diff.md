# Moonraker upstream diff inventory

This document inventories Eryone-specific Moonraker changes extracted from the
legacy `thinker400_klipperscreen` repo and maps them to migration categories.

## Baseline provenance

- **Legacy root import commit:** `1ba5fc27d2691074a0147a914b792d107ab056fe` (`x400`, 2025-06-02)
- **Upstream repo:** `Arksine/moonraker`
- **Baseline SHA used for comparison:** `0310d0b` (2025-05-22)
- **Method:** date-based baseline selection and blob-hash comparison on
  `moonraker/` runtime paths. See `docs/upstream_baselines.md`.

## Snapshot-level comparison (legacy root vs upstream baseline)

| same | modified | added | missing |
|------|----------|-------|---------|
| 13   | 46       | 6     | 14      |

As with Klipper, most of this is snapshot drift from a vendored tree. The
actual net custom delta after root import is much smaller.

## Net custom delta after the legacy root import

`git diff 1ba5fc2..HEAD -- moonraker/` yields two files:

1. `moonraker/moonraker/components/file_manager/file_manager.py`
2. `moonraker/moonraker/components/file_manager/metadata.py`

Patch sizes:

- `file_manager.py`: `+1 / -1` (hard-coded upload temp path)
- `metadata.py`: `+390 / -147` (large parser rewrite)

## A/B/C/D inventory

| Legacy path | Category | Evidence | Planned disposition |
|-------------|----------|----------|---------------------|
| `moonraker/moonraker/components/file_manager/metadata.py` | **B** | Large rewrite touching thumbnail parsing and metadata extraction behaviors | Re-implement as `moonraker-eryone/components/eryone_metadata.py` that extends upstream parser classes and only overrides Eryone slicer semantics. |
| `moonraker/moonraker/components/file_manager/file_manager.py` | **B** | Upload temp path changed from `tempfile.gettempdir()` to hard-coded `/home/mks/printer_data/gcodes/` | Do not carry this patch; use stock upstream Moonraker temp upload behavior. |
| `moonraker/moonraker/components/machine.py` | **B** | Referenced by legacy provisioning (`all/relink_conf.sh`) for direct copy into installed Moonraker tree | Re-check against baseline during implementation; port only if behavior is still needed for X400 hardware management. |
| Moonraker config customizations (`config/moonraker.conf`, timelapse include, update_manager entries) | **C** | Stored outside source tree in legacy repo | Move into installer-rendered config templates under `config/`. |
| Remaining broad snapshot drift in vendored Moonraker tree | **D** | 46 modified + 14 missing files at snapshot level | Do not port wholesale; keep upstream Moonraker untouched and implement only categorized B/C items. |

## Notes for Phase 3

- `metadata.py` behavior should be split into narrow parser extensions with
  tests per slicer flavor.
- Any unavoidable monkeypatch must be version-gated by upstream Moonraker SHA
  and fail loudly on mismatch.

## Phase 3 implementation status

- ✅ `components/eryone_metadata.py` added as a metadata overlay that preserves
  upstream parsing and appends optional `eryone_hints`.
- ✅ Legacy `machine.py` replacement path closed: no net X400-specific behavior
  remains after root-import delta analysis, so no machine overlay is installed.
- ✅ Stock Moonraker upload temp-path behavior is used; no `file_manager`
  monkeypatch is installed.
