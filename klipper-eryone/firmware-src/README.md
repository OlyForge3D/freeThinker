# Firmware source staging

This directory holds X400-specific MCU sources that cannot yet be represented
as pure host-side Klipper extras.

Current decision (Phase 2): treat `pressure_sensor.c` as an out-of-tree patch
to upstream Klipper firmware targets, version-gated by tested upstream SHAs.

Planned follow-up:

1. Import the legacy `src/pressure_sensor.c` source with history annotation.
2. Add target-specific build instructions for X400 toolhead boards.
3. Produce versioned binaries and checksums in `../firmware/`.
