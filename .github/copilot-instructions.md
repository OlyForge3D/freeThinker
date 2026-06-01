# Copilot instructions — thinker-x400 (freeThinker)

This repo is a clean **overlay** on top of an unmodified MainsailOS install
(Klipper + Moonraker + KlipperScreen) that adds Eryone Thinker X400 support.
It is **not** a fork of any upstream project. Keep that boundary intact.

## Architecture in one paragraph

Eryone-specific behavior is split into four plugin trees that match the
upstream extension points:

- `klipper-eryone/extras/eryone_*.py` — Klipper extras (auto-loaded by
  `[name ...]` config sections). Also holds out-of-tree pressure-sensor
  firmware sources and prebuilt `.hex` artifacts under `firmware/`.
- `moonraker-eryone/components/eryone_*.py` — Moonraker components.
- `klipperscreen-eryone/panels/eryone_*.py` — KlipperScreen panels (AGPL-3.0;
  the rest of the repo is GPL-3.0).
- `installer/` — idempotent bash installer that **symlinks** the plugin files
  into the user's upstream `~/klipper`, `~/moonraker`, `~/KlipperScreen`
  installs and renders Jinja templates from `config/printer/templates/` into
  `~/printer_data/config/`. No upstream files are modified in place.

Hardware variants are encoded as `installer/variants/<variant>.env` (e.g.
`x400_300.env`, `x400_350.env`) declaring `VARIANT_ID`, `BED_SIZE_X/Y`,
`TOOLHEAD_REV`, `HOTEND_MAX_TEMP`, `EECAN_INCLUDE`,
`PRESSURE_SENSOR_FIRMWARE`. The installer sources the chosen variant, renders
templates, and installs the matching prebuilt MCU firmware from
`klipper-eryone/firmware/`.

See `docs/architecture.md` for the full picture and each plugin tree's
`docs/upstream_diff.md` for the hunk-level inventory vs upstream.

## Non-negotiable conventions

1. **No upstream forks.** New Eryone behavior goes in as a klippy extra,
   Moonraker component, KlipperScreen panel, or installer logic. If that's
   truly impossible, prefer an upstream PR, then a `quilt`-style patch under
   `<component>/patches/` pinned to an upstream SHA. There are currently
   **no** active local source patches — keep it that way unless necessary.
2. **No hard-coded paths, users, or passwords** in installer scripts.
   Discover the printer user via `detect_printer_user` in
   `installer/lib/common.sh` (honors `INSTALL_PRINTER_USER`, then
   `systemctl show -p User klipper`, then current uid). Resolve home with
   `resolve_home_for_user`.
3. **Idempotent installer steps.** Re-running `./install.sh` must converge.
   Numbered steps under `installer/steps/NN_*.sh` are sourced in order and
   share helpers from `installer/lib/common.sh` (`log_info`, `fail`,
   `render_template`, `install_file`, `install_file_if_missing`, ...).
4. **Shell script header.** Every tracked `.sh` file has, immediately after
   the shebang:
   ```sh
   # File: <repo-relative-path>
   # Purpose: <one-line description of behavior and scope>
   #
   ```
   Keep `Purpose` concrete, especially for scripts that change printer
   state, rewrite config, or flash firmware.
5. **License split.** Anything under `klipperscreen-eryone/` is **AGPL-3.0**
   (matches upstream KlipperScreen). Everywhere else is **GPL-3.0**. Don't
   move code across that boundary without updating headers.
6. **Plugin namespacing.** All plugin filenames are prefixed `eryone_` so
   they cannot collide with upstream modules; preserve that prefix.
7. **Intentionally out of scope** (do not re-add): Eryone farm/cloud
   services, `SCAN_ALL_PRINTER`/`scan.sh`, the Moonraker file-manager
   upload-path monkeypatch (`eryone_file_manager`), and broad rewrites of
   upstream KlipperScreen core panels (`extrude.py`, `print.py`,
   `bed_mesh.py`).

## Build / test / lint

CI runs in `.github/workflows/{lint,test}.yml`. Locally:

```sh
# Lint (matches CI scope exactly)
shellcheck install.sh uninstall.sh update.sh \
  installer/lib/common.sh installer/steps/*.sh config/scripts/*.sh
ruff check klipper-eryone moonraker-eryone klipperscreen-eryone

# Unit tests
pytest tests/klipper tests/moonraker
pytest tests/klipper/test_eryone_plr.py            # single file
pytest tests/klipper/test_eryone_plr.py::test_name # single test

# Installer tests (bash, via bats)
bats tests/installer/*.bats
bats tests/installer/install_help.bats             # single file
```

Notes:

- `ruff.toml` only sets per-file ignores for `klipperscreen-eryone/panels/eryone_*.py`
  (KlipperScreen panels do gtk imports at module top after `gi.require_version`,
  so `E402`/`F401`/`F821` etc. are tolerated there). Don't broaden ignores
  elsewhere.
- Plugin subdirectory READMEs explain how to mock klippy / moonraker in tests.
- `release.yml` builds tagged tarball + SHA256 release assets; don't invoke
  manually.

## Installer entry points

```sh
./install.sh --variant x400_350 --hotend 350
./install.sh --variant x400_350 --hotend 350 --fresh-rebuild
./install.sh --variant x400_350 --hotend 350 --flash-mcus \
  --mcu-env-file config/support/mcu/mcu-update.env
```

`--hotend` is prompted interactively if omitted; pass it explicitly for
CI/non-interactive runs. The installer registers this repo with Moonraker's
`update_manager` via `config/printer/templates/moonraker.thinker-x400.conf.j2`.

## Commits

Conventional Commits encouraged but not enforced, e.g.
`feat(installer): add x400_300 variant`,
`fix(klipper-eryone): handle rc522 read timeout`.
