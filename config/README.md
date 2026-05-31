# config/

Printer config snippets and Jinja templates dropped into
`~/printer_data/config/` by the installer.

Imported from legacy baseline in Phase 6 with a variant-aware
`templates/printer.cfg.j2`.

## Layout

```
config/
├── *.cfg           # snippets rendered by installer then included from printer.cfg
├── scripts/        # helper scripts for gcode_shell_command hooks
├── templates/      # Jinja templates rendered by the installer
└── README.md
```

## X400 hook scripts

- `scripts/bed_object.sh` invokes `scripts/cv.py` for the `DETECT_BED_OBJECT`
  hook used by `PRINT_START` when `use_ai` is enabled.

## Machine-specific files

- `canuid.cfg.template` is the tracked template with placeholder UUIDs.
- `canuid.cfg` is treated as machine-specific during install/update.
  The installer seeds `canuid.cfg` from the template only when missing and
  preserves an existing one on subsequent runs.
- Installer fails fast if `canuid.cfg` still contains template placeholders
  (`000000000000`) or malformed UUID values.
