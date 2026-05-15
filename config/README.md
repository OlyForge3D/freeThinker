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
