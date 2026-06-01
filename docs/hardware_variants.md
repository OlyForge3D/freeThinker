# Hardware variants

This project currently supports two explicit hotend-profile variant IDs used by
`install.sh --variant <id>`.

## Supported hotend profiles

| Variant id  | Toolhead board      | Hotend max | EECAN include    | Pressure sensor firmware |
|-------------|---------------------|------------|------------------|--------------------------|
| `x400_300`  | `standard`          | 300°C      | `EECAN1_300.cfg` | `stm32_pressure_sensor_300.hex` |
| `x400_350`  | `high_temp_adc_v1`  | 350°C      | `EECAN1_350.cfg` | `stm32_pressure_sensor_350.hex` |

350C upgrade guide:
<https://eryonewiki.com/en/home/HotendUpgradeto350%C2%B0CAssemblyProcess>

## Legacy command mapping

The wiki references console commands from Eryone's legacy KlipperScreen fork:

- `W` (query CAN UUIDs)
- `V1_350` / `V1_300` (switch toolhead config include)

Backward compatibility is restored in this project via macros in
`config/printer/x400.cfg`, so these commands are accepted in the gcode console
when the X400 macro set is loaded.

Preferred equivalents in `freeThinker`:

- CAN UUID query: `~/klipper/scripts/canbus_query.py can0`
- Katapult query mode: `~/katapult/scripts/flashtool.py -i can0 -q`

In `thinker-x400`, hotend profile selection is handled by installer args
instead of patched KlipperScreen console code:

- `./install.sh --variant <x400_300|x400_350> --hotend <300|350>`

## Identification

The installer currently requires explicit `--variant` and, for non-interactive
runs, explicit `--hotend`. Automatic hardware detection is not implemented.

## Open questions

Open questions for future expansion:

- Additional X400 SKUs (if any) beyond current hotend-profile mapping.
- Whether 2.85 mm hotend support should become another `--hotend` profile.
