# Firmware source

This directory holds X400-specific MCU sources that are not represented as
pure host-side Klipper extras.

Current decision (Phase 2): treat `pressure_sensor.c` as an out-of-tree patch
to upstream Klipper firmware targets, version-gated by tested upstream SHAs.

Current status:

1. `pressure_sensor.c` has been imported from legacy root commit
   `1ba5fc27d2691074a0147a914b792d107ab056fe`.
2. Legacy pressure-sensor binaries are staged in `../firmware/` with checksums
   tracked in `../firmware/MANIFEST.json`.
3. Future rebuilds should publish updated artifacts and checksums in the same
   manifest.
