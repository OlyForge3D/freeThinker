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
- ✅ `extras/eryone_plr.py` implemented to replace the legacy
  `virtual_sdcard.py` PLR patch.
- ✅ Klipper patch queue retired; `klipper-eryone/patches/` now has no active
  patches.
- ✅ Pressure-sensor source and firmware artifacts are staged with checksums in
  `firmware/MANIFEST.json`.

## Pressure sensor: two distinct hardware paths (live-printer finding)

Recon of the running X400 (`reference/printer-home`, EECAN toolhead firmware
build `20240409_151218`) shows there are **two unrelated strain/pressure probe
designs**, and this printer uses the simpler one:

| Path | How the trigger reaches the host | Host module needed? | Firmware |
|------|----------------------------------|---------------------|----------|
| **EECAN digital probe** (this printer) | Toolhead MCU does the strain math and exposes a plain digital endstop on `EECAN:gpio21`; baseline reset via `output_pin reset_probe` (gpio0) and `rt_probe_adc` (gpio2). | **No.** Stock Klipper `[probe]` + `[output_pin]` + `[gcode_macro]`. | Already-flashed EECAN toolhead build (no-flash compatible). |
| **STM32 BD-probe board** (legacy variant) | A standalone STM32 sensor MCU speaks the BDsensor I2C protocol (`config_I2C_BD` / `I2CBD` / `BDendstop_home`, CMD codes 1015–1026). | Yes — the 1215-line BDsensor host module. | `firmware/stm32_pressure_sensor_{300,350}.hex` + `firmware-src/pressure_sensor.c`. |

### Live config (EECAN path) — verified from klippy.log / EECAN.cfg

```ini
[probe]
pin: EECAN:gpio21
x_offset: 0
y_offset: 0
speed: 1.5
samples: 2
samples_result: median
sample_retract_dist: 3
samples_tolerance: 0.05
samples_tolerance_retries: 5
# z_offset is set by SAVE_CONFIG (live value -0.12)

[output_pin reset_probe]   # gpio0 — strain-gauge baseline reset
pin: EECAN:gpio0
pwm: False
value: 1

[output_pin rt_probe_adc]  # gpio2 — real-time ADC reset line
pin: EECAN:gpio2
pwm: False
value: 1

[gcode_macro RS_probe]     # reset cycle invoked before probing
[gcode_macro resetON] / [gcode_macro resetOFF]
[gcode_macro reset_probe_adc]
```

All of the above are **stock Klipper sections** — nothing here loads
`extras/pressure_sensor.py`. There is no `[pressure_sensor]` / `[BDsensor]`
section anywhere in the live config tree.

### Disposition (corrected)

- **No-flash migration of this printer requires no pressure-sensor host
  module.** Mainline Klipper's built-in `probe.py` + `output_pin` + macros
  fully drive the EECAN strain probe against the existing flashed firmware.
- The migration must **preserve the probe/reset config and macros** verbatim;
  they are already captured in `config/EECAN.cfg` (`[probe]`,
  `[output_pin reset_probe]`, `[output_pin rt_probe_adc]`, and the
  `RS_probe` / `resetON` / `resetOFF` / `reset_probe_adc` macros).
- `extras/pressure_sensor.py` (BDsensor I2C) is **legacy/dormant** for this
  printer. It is only relevant to the standalone STM32 BD-probe variant. If
  that variant is ever targeted, port it as `extras/eryone_pressure_sensor.py`
  with a namespaced `[eryone_pressure_sensor]` section and keep the MCU command
  strings byte-identical to stay no-flash with the `stm32_pressure_sensor_*.hex`
  artifacts. Until then it is **not** ported (avoids shipping a 1215-line
  module the hardware never loads).
