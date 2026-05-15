# Variants

Each `*.env` file in this directory describes one Thinker X400 hardware
configuration. The installer sources the selected file and uses the
exported variables to render config templates and pick firmware.

Required variables (subject to refinement during Phase 6):

| Variable                  | Example                                 |
|---------------------------|-----------------------------------------|
| `VARIANT_ID`              | `x400_350`                              |
| `BED_SIZE_X`              | `350`                                   |
| `BED_SIZE_Y`              | `350`                                   |
| `TOOLHEAD_REV`            | `high_temp_adc_v1`                      |
| `HOTEND_MAX_TEMP`         | `350`                                   |
| `EECAN_INCLUDE`           | `EECAN1_350.cfg`                        |
| `PRESSURE_SENSOR_FIRMWARE` | `stm32_pressure_sensor_350_<sha>.hex`  |

Current variants:

- `x400_300.env`
- `x400_350.env`
