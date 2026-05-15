# Temporary Klipper patch queue

These patches are extracted from legacy Thinker X400 behavior and are kept as
**temporary fallbacks** while equivalent plugin-based implementations are built.

## Policy

1. Prefer out-of-tree extras in `../extras/` over patching upstream Klipper.
2. Keep patch count minimal and explicitly justified.
3. Pin and test against a known upstream Klipper SHA before applying.
4. Fail fast if patches do not apply cleanly.

## Apply example

```sh
cd ~/klipper
git checkout <tested-sha>
git am /path/to/thinker-x400/klipper-eryone/patches/*.patch
```

## Current queue

- `0001`: allow `probe_count` min value of `2` in bed_mesh
- `0002`: suppress chamber verify_heater debug response
- `0003`: add legacy PLR hooks to `virtual_sdcard`
- `0004`: reduce queue logger backup count
