# Variants

Each `*.env` file in this directory describes one Thinker X400 hardware
configuration. The installer sources the selected file and uses the
exported variables to determine hotend-profile defaults. Hotend-specific settings
are selected at install time via `--hotend <300|350>` (or prompt).

Required variables (subject to refinement during Phase 6):

| Variable                  | Example                                 |
|---------------------------|-----------------------------------------|
| `VARIANT_ID`              | `x400_350`                              |
| `BED_SIZE_X`              | `400`                                   |
| `BED_SIZE_Y`              | `400`                                   |
| `TOOLHEAD_REV`            | `high_temp_adc_v1` (hotend default)     |
| `HOTEND_MAX_TEMP`         | `350` (hotend default)                  |
| `EECAN_INCLUDE`           | `EECAN1_350.cfg` (hotend default)       |
| `PRESSURE_SENSOR_FIRMWARE` | `stm32_pressure_sensor_350_<sha>.hex`  |

Current variants:

- `x400_300.env`
- `x400_350.env`
