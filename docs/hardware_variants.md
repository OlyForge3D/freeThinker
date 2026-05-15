# Hardware variants

> **Status:** placeholder. To be filled in during Phase 1 inventory.

This document will enumerate the supported Thinker X400 hardware
configurations and the variant file each one maps to.

## Known variants

| Variant id  | Bed     | Toolhead board   | Hotend max | Pressure sensor firmware            |
|-------------|---------|------------------|------------|-------------------------------------|
| `x400_300`  | 300×300 | TBD              | TBD        | `stm32_pressure_sensor_300_<sha>.hex` |
| `x400_350`  | 350×350 | High-temp ADC    | 350°C      | `stm32_pressure_sensor_350_<sha>.hex` |

## Identification

The installer should be able to auto-detect variant where possible (e.g.,
by querying the toolhead board over CAN, or by reading a marker file
written at first boot). Until that exists, variant must be passed
explicitly with `--variant`.

## Open questions

- Are there additional bed sizes (e.g., 250mm) shipping under the X400
  name?
- How many toolhead board revisions exist, and which ones need separate
  firmware?
- Is the 2.85mm-filament hotend a separate variant, or a sub-flag?
