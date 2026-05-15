# Developer setup

> **Status:** placeholder. Will be expanded as the installer and tests
> come online.

## Required tools

- Python 3.11+
- `ruff`, `pytest`
- `shellcheck`, `bats`
- `gh` (GitHub CLI) for release tasks

## Layout

See [`architecture.md`](architecture.md).

## Testing locally

```sh
# Lint
shellcheck installer/**/*.sh
ruff check klipper-eryone moonraker-eryone klipperscreen-eryone

# Unit tests
pytest tests/klipper tests/moonraker

# Installer tests (in a MainsailOS-like Docker container)
bats tests/installer/
```
