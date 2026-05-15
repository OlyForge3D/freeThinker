# Architecture

## Goal

Ship Eryone Thinker X400 functionality as a clean overlay on top of an
unmodified [MainsailOS] install, without forking Klipper, Moonraker, or
KlipperScreen.

## Component map

```
                 ┌────────────────────────────────────────────────┐
                 │                MainsailOS host                 │
                 │                                                │
   ┌─────────────┼─► /home/<user>/klipper           (upstream)    │
   │             │     └─ klippy/extras/eryone_*.py  ← symlinks   │
   │             │                                                │
   │             ├─► /home/<user>/moonraker         (upstream)    │
   │ thinker-x400│     └─ moonraker/components/eryone_*.py        │
   │   installer │                                                │
   │             ├─► /home/<user>/KlipperScreen     (upstream)    │
   │             │     └─ panels/eryone_*.py        ← symlinks    │
   │             │                                                │
   │             ├─► /home/<user>/printer_data/config/             │
   │             │     ├─ x400.cfg                                │
   │             │     ├─ EECAN1_<variant>.cfg                    │
   │             │     ├─ chamber.cfg / runout.cfg / plr.cfg ...  │
   │             │     └─ moonraker.conf  (update_manager entry)  │
   │             │                                                │
   │                                                              │
   │             (no upstream files modified in place)            │
   └──────────────────────────────────────────────────────────────┘
```

## Why plugins, not patches

Eryone's current `thinker400_klipperscreen` repo bakes edits directly into
copies of Klipper, Moonraker, and KlipperScreen, then copies those files
over the upstream installs at provision time. This makes upstream tracking
impossible — any update to Klipper or Moonraker either silently overwrites
the Eryone edits or has to be manually re-applied.

By contrast:

- **Klipper** auto-loads `klippy/extras/<name>.py` modules. Adding a file
  is enough to register a new config section (`[name ...]`).
- **Moonraker** has a real component system (`moonraker/components/*.py`)
  with subclassable extractors and registered hooks.
- **KlipperScreen** loads panels by module name from `panels/`. Adding new
  panel files plus menu config entries is sufficient for new screens.
  Behavioral changes to existing panels are best split into bug-fix PRs
  (upstreamed) and X400-only UI (new panels referenced from menu config).

The installer ships these plugin files as symlinks from this repo into the
upstream installs, so `git pull && ./update.sh` deploys updates without
mutating upstream files.

## Variant selection

Hardware variants (300mm vs 350mm bed, toolhead board generations, hotend
max temperatures) are encoded as `installer/variants/<variant>.env` files.
The installer:

1. Sources the chosen variant file.
2. Renders Jinja templates under `config/templates/` into
   `~/printer_data/config/`.
3. Installs the matching prebuilt MCU firmware from
   `klipper-eryone/firmware/`.

A variant file declares (at least): `BED_SIZE`, `TOOLHEAD_REV`,
`HOTEND_MAX_TEMP`, `EECAN_INCLUDE`, `PRESSURE_SENSOR_FIRMWARE`.

## Upstream-tracking discipline

Each plugin subdirectory has a `docs/upstream_diff.md` that lists every
hunk that came from a behavioral edit to upstream code, with one of:

- ✅ Upstream PR (link).
- 🔁 Reworked as plugin hook.
- 🩹 Maintained as quilt patch under `<component>/patches/`, pinned to
  upstream SHA `<sha>`.

Any patch under `<component>/patches/` must declare the upstream SHA it
applies to and be re-validated on every dependency bump.

Current status: there are no active local source patches in this repo.

[MainsailOS]: https://github.com/mainsail-crew/MainsailOS
