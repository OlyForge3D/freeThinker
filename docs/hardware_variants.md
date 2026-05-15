# Hardware variants

This project currently supports two explicit variant IDs used by
`install.sh --variant <id>`.

## Known variants

| Variant id  | Bed     | Toolhead board   | Hotend max | EECAN include    | Pressure sensor firmware |
|-------------|---------|------------------|------------|------------------|--------------------------|
| `x400_300`  | 300×300 | `standard`       | 300°C      | `EECAN1_300.cfg` | `stm32_pressure_sensor_300.hex` |
| `x400_350`  | 350×350 | `high_temp_adc_v1` | 350°C    | `EECAN1_350.cfg` | `stm32_pressure_sensor_350.hex` |

## Identification

The installer currently requires explicit `--variant`; automatic hardware
detection is not implemented yet.

## Open questions

Open questions for future expansion:

- Additional X400 SKUs (if any) beyond 300/350 beds.
- Whether 2.85 mm hotend support should become its own variant or a feature
  flag inside each variant.
