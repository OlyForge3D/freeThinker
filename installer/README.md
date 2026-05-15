# installer/

Idempotent bash installer that overlays the Thinker X400 plugins, configs,
and services on top of an unmodified MainsailOS install.

## Current status

Implemented in Phase 5/6:

- Variant-aware install entrypoint (`install.sh --variant x400_300|x400_350`)
- Preflight + path/user autodetection
- Symlink deployment for Klipper extras, Moonraker components, and
  KlipperScreen panels
- Config rendering (`printer.cfg` template + Moonraker include snippet)
- Optional service installation (`ENABLE_OPTIONAL_SERVICES=1`)
- Firmware asset deployment (manifest + variant binaries) and slicer profiles

## Layout

```
installer/
├── lib/              # shared bash helpers (logging, detection, services)
├── steps/            # numbered idempotent steps run in order
└── variants/         # per-hardware-variant env files
```

## Design rules

- No hard-coded paths, usernames, or passwords. All discovered at runtime.
- Every step must be re-runnable; symlinks preferred over copies.
- The installer never edits `printer.cfg` in place. It drops new files and
  references them with `[include ...]`.
- Moonraker `update_manager` is configured to track this repo so users see
  updates in Mainsail.

## Usage

```sh
./install.sh --variant x400_350
```

Optional flags/environment:

- `--printer-user <user>`: override auto-detected printer user.
- `--force`: continue despite preflight warnings.
- `ENABLE_OPTIONAL_SERVICES=1`: install `services/*.service.in`.
- `RESTART_SERVICES=1`: restart Klipper/Moonraker at end.
