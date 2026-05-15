# Hardware variants

This project currently supports two explicit bed-size variant IDs used by
`install.sh --variant <id>`.

## Bed variants

| Variant id  | Bed     |
|-------------|---------|
| `x400_300`  | 300×300 |
| `x400_350`  | 350×350 |

## Hotend profiles

Select with `--hotend <300|350>` (or via interactive prompt on TTY):

| Hotend | Toolhead board      | Hotend max | EECAN include    | Pressure sensor firmware |
|--------|---------------------|------------|------------------|--------------------------|
| `300`  | `standard`          | 300°C      | `EECAN1_300.cfg` | `stm32_pressure_sensor_300.hex` |
| `350`  | `high_temp_adc_v1`  | 350°C      | `EECAN1_350.cfg` | `stm32_pressure_sensor_350.hex` |

350C upgrade guide:
<https://eryonewiki.com/en/home/HotendUpgradeto350%C2%B0CAssemblyProcess>

## Legacy command mapping

The wiki references console commands from Eryone's legacy KlipperScreen fork:

- `W` (query CAN UUIDs)
- `V1_350` / `V1_300` (switch toolhead config include)

In `thinker-x400`, hotend profile selection is handled by installer args
instead of patched KlipperScreen console code:

- `./install.sh --variant <x400_300|x400_350> --hotend <300|350>`

Re-running `install.sh` with a different `--hotend` value switches profiles.

## Identification

The installer currently requires explicit `--variant` and, for non-interactive
runs, explicit `--hotend`. Automatic hardware detection is not implemented.

## Open questions

Open questions for future expansion:

- Additional X400 SKUs (if any) beyond 300/350 beds.
- Whether 2.85 mm hotend support should become another `--hotend` profile.
