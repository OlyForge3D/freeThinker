# installer/

Idempotent bash installer that overlays the Thinker X400 plugins, configs,
and services on top of an unmodified MainsailOS install.

> **Status:** scaffold only. Implementation lands in Phase 5.

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
