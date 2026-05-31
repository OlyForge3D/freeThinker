# config/

Configuration sources are split by intent to keep deployable printer files
separate from repo-only support assets.

## Layout

```
config/
├── printer/
│   ├── *.cfg          # snippets installed into ~/printer_data/config/
│   ├── templates/     # Jinja templates rendered by the installer
│   └── scripts/       # helper scripts installed to ~/printer_data/config/scripts/
├── support/
│   ├── mcu/           # MCU build/flash profile sets and env example
│   └── host-input/    # host-side input config snippets (not installed by step 50)
└── README.md
```

## Installer behavior

- `installer/steps/50_configs.sh` installs files from `config/printer/` only.
- Runtime destination remains `~/printer_data/config/`.
- `config/printer/canuid.cfg.template` is copied as template reference.
- `canuid.cfg` is seeded only if missing, then preserved across re-runs.
- Installer fails fast if `canuid.cfg` contains placeholder or malformed UUIDs.

## X400 hook scripts

- `config/printer/scripts/bed_object.sh` invokes `cv.py` for
  `DETECT_BED_OBJECT` used by `PRINT_START` when `use_ai` is enabled.
