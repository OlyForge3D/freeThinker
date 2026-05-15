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

- **`klipper-eryone/`** — Klipper extras (`klippy/extras/eryone_*.py`) and,
  where unavoidable, an out-of-tree firmware patch series. GPL-3.0.
- **`moonraker-eryone/`** — Moonraker components
  (`moonraker/components/eryone_*.py`). GPL-3.0.
- **`klipperscreen-eryone/`** — KlipperScreen drop-in panels and overrides.
  AGPL-3.0 (matches upstream KlipperScreen).
- **`installer/`** — idempotent bash installer that overlays the above onto
  an unmodified MainsailOS install. No hard-coded users or passwords.
- **`config/`** — variant-aware printer config templates (300mm / 350mm
  bed, toolhead board generations).
- **`services/`** — templated systemd units (`farm3d`, `cloud_mq`).
- **`profiles/`** — OrcaSlicer / Bambu Studio slicer profiles.

## Hardware variants

| Variant   | Bed      | Toolhead | Hotend max |
|-----------|----------|----------|------------|
| `x400_300` | 300×300 | standard | 300°C      |
| `x400_350` | 350×350 | high_temp_adc_v1 | 350°C |

See [`docs/hardware_variants.md`](docs/hardware_variants.md).

## Install (development preview)

```sh
git clone https://github.com/jpapiez/thinker-x400.git ~/thinker-x400
cd ~/thinker-x400
./install.sh --variant x400_350
```

The installer will:

1. Verify it is running on MainsailOS.
2. Discover the printer-data user.
3. Install the Klipper extras, Moonraker components, and KlipperScreen
   panels via symlink.
4. Drop variant-aware configs into `~/printer_data/config/`.
5. Install templated systemd units.
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
