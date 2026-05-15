# Thinker X400

A clean overlay for [MainsailOS] that adds Eryone Thinker X400 support
without forking Klipper, Moonraker, or KlipperScreen.

> **Status:** active development. Plugin overlays, installer pipeline, variant
> templates, and firmware manifests are implemented; continue validating on
> target hardware before production rollout.

## What this is

Eryone's stock firmware for the Thinker X400 ships as a pre-baked Armbian
image with hand-edited copies of Klipper, Moonraker, KlipperScreen, and a
collection of provisioning scripts wired to a specific user (`mks`) and a
hard-coded sudo password. Updating any upstream component is effectively
impossible without losing X400 functionality.

This repository takes the Eryone-specific functionality out of the vendored
forks and ships it as:

- **`klipper-eryone/`** — Klipper extras (`klippy/extras/eryone_*.py`) plus
  out-of-tree pressure-sensor firmware source/artifacts. GPL-3.0.
- **`moonraker-eryone/`** — Moonraker components
  (`moonraker/components/eryone_*.py`). GPL-3.0.
- **`klipperscreen-eryone/`** — KlipperScreen drop-in namespaced panel modules.
  AGPL-3.0 (matches upstream KlipperScreen).
- **`installer/`** — idempotent bash installer that overlays the above onto
  an unmodified MainsailOS install. No hard-coded users or passwords.
- **`config/`** — hotend-profile-aware printer config templates.
- **`profiles/`** — OrcaSlicer / Bambu Studio slicer profiles.

## Eryone additions over mainline

This is the current shipped delta in `thinker-x400` over stock Klipper,
Moonraker, KlipperScreen, and MainsailOS.

| Upstream layer | Additions in this repo |
|----------------|------------------------|
| **Klipper** | `klipper-eryone/extras/eryone_plr.py` (power-loss resume wrapper for `SDCARD_PRINT_FILE`), `klipper-eryone/extras/eryone_rc522.py` (RFID reader + `M410`), plus out-of-tree pressure-sensor source/artifacts (`firmware-src/pressure_sensor.c`, `firmware/stm32_pressure_sensor_{300,350}.hex`, `firmware/MANIFEST.json`). |
| **Moonraker** | `moonraker-eryone/components/eryone_metadata.py` adds parsing of `; ERYONE_*=` header hints into metadata (`eryone_hints`), and `config/templates/moonraker.thinker-x400.conf.j2` adds `[eryone_metadata]` + `[update_manager thinker-x400]`. |
| **KlipperScreen** | Namespaced panels only: `eryone_chgfilament.py`, `eryone_statis.py`, `eryone_tuning_settings_panel.py` (installed via symlink by `installer/steps/40_klipperscreen_plugin.sh`). |
| **MainsailOS / printer_data config** | No Mainsail frontend fork. The overlay ships X400-specific config/macros (`config/templates/printer.cfg.j2`, `config/x400.cfg`, `config/chamber.cfg`, `config/plr.cfg`, `config/rc522.cfg`, `config/runout.cfg`, `config/v1_1.cfg`, `config/v1_2.cfg`, etc.) and runtime helper scripts (`config/scripts/bed_object.sh`, `config/scripts/cv.py`, `config/scripts/git_pull.sh`). |

### Intentionally not carried

- No farm/cloud service stack.
- No `SCAN_ALL_PRINTER` / `scan.sh` LAN scan hook.
- No Moonraker file-manager upload-path monkeypatch (`eryone_file_manager`).
- No broad KlipperScreen core-panel rewrites (`extrude.py`, `print.py`, `bed_mesh.py`) in this repo.

Detailed per-component hunk inventories are in:

- `klipper-eryone/docs/upstream_diff.md`
- `moonraker-eryone/docs/upstream_diff.md`
- `klipperscreen-eryone/docs/upstream_diff.md`

## Hardware variants

| Variant profile | Meaning | Hotend max |
|-----------------|---------|------------|
| `x400_300`      | Standard hotend profile | 300°C |
| `x400_350`      | High-temp hotend profile | 350°C |

See [`docs/hardware_variants.md`](docs/hardware_variants.md).

## Install (development preview)

```sh
git clone https://github.com/jpapiez/thinker-x400.git ~/thinker-x400
cd ~/thinker-x400
./install.sh --variant x400_350 --hotend 350
```

If `--hotend` is omitted in an interactive terminal, the installer prompts for
`300` or `350`. For non-interactive installs (CI/automation), pass
`--hotend` explicitly.

350C upgrade guidance:
<https://eryonewiki.com/en/home/HotendUpgradeto350%C2%B0CAssemblyProcess>

The installer will:

1. Verify it is running on MainsailOS.
2. Discover the printer-data user.
3. Install the Klipper extras, Moonraker components, and KlipperScreen
   panels via symlink.
4. Drop variant-aware configs into `~/printer_data/config/`.
5. Keep legacy Eryone farm/cloud services out of scope.
6. Register this repo with Moonraker's `update_manager`.

## Licensing

- Repository default: **GPL-3.0** — see [`LICENSE`](LICENSE).
- `klipperscreen-eryone/` subtree: **AGPL-3.0** — see
  [`klipperscreen-eryone/LICENSE`](klipperscreen-eryone/LICENSE).
- See [`LICENSING.md`](LICENSING.md) for the rationale.

## History

The original combined repo lives at
[`jpapiez/thinker400_klipperscreen`](https://github.com/jpapiez/thinker400_klipperscreen)
and is preserved as a historical reference.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

[MainsailOS]: https://github.com/mainsail-crew/MainsailOS
