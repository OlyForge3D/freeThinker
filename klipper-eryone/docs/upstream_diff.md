# Klipper upstream diff inventory

> **Status:** placeholder. Populated in Phase 1.

For each hunk that originates from Eryone's vendored copy of Klipper, this
file records its target category:

- **A** — additive new file. Repackaged as a `klippy/extras/eryone_*.py`
  module.
- **B** — behavioral patch to an upstream file. Reworked as a hook,
  monkeypatch, subclass, or upstreamed PR.
- **C** — config-only difference. Lives under `config/`.
- **D** — dead / obsolete. Dropped.

## Inventory

| Path (in legacy repo)                          | Category | Disposition |
|------------------------------------------------|----------|-------------|
| `klipper/klippy/extras/rc522.py`               | A        | Rename to `eryone_rc522.py` (Phase 2). |
| `klipper/src/pressure_sensor.c`                | A/B      | Decision pending: out-of-tree firmware patch vs upstream PR. |
| `klipper/klippy/extras/bed_mesh.py` (edits)    | B        | TBD — analyze hunks. |
| `klipper/klippy/extras/verify_heater.py` (edits) | B      | TBD. |
| `klipper/klippy/extras/virtual_sdcard.py` (edits) | B     | TBD. |
| `klipper/klippy/extras/angle.py` (edits)       | B        | TBD. |
| `klipper/klippy/extras/spi_temperature.py` (edits) | B    | TBD. |
