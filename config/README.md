# config/

Printer config snippets and Jinja templates dropped into
`~/printer_data/config/` by the installer.

> **Status:** scaffold. Configs are imported from the legacy repo and
> templated in Phase 6.

## Layout

```
config/
├── *.cfg           # static snippets included from printer.cfg
├── templates/      # Jinja templates rendered by the installer
└── README.md
```
