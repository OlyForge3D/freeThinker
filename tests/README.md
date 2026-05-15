# tests/

```
tests/
├── installer/   # bats tests run inside a MainsailOS-like Docker container
├── klipper/     # pytest for klippy extras (mock klippy.reactor etc.)
└── moonraker/   # pytest for moonraker components
```

Current tests:

- `tests/klipper/test_eryone_rc522.py`
- `tests/moonraker/test_eryone_metadata_overlay.py`
- `tests/installer/install_help.bats`
