# MCU Build + Katapult Flash Workflow

This folder contains a repeatable workflow to compile and deploy mainline
Klipper firmware for both Thinker MCUs (mainboard + CAN toolhead).

The migration flow (`scripts/migrate/10_migrate_to_freethinker.sh`) now ensures
`~/katapult` is cloned/updated from upstream so bootloader builds use the latest
Katapult source instead of legacy `canboot` checkouts.

## Scripts

- `discover_can_uuids.sh` - query uninitialized CAN devices.
- `build_katapult_bootloaders.sh` - build Katapult bootloaders using exact imported X400 profiles.
- `build_klipper_mcus.sh` - build separate Klipper binaries using profile files.
- `flash_klipper_mcus_katapult.sh` - flash both binaries using Katapult.
- `request_bootloader_and_query.sh` - request Katapult mode and verify with `-q` (no flashing).
- `update_both_mcus.sh` - end-to-end wrapper (build + flash, optional local `canuid.cfg` rewrite).
- `report_reference_offsets.py` - inspect captured BIN/HEX/UF2 artifacts in `reference/printer-home` and report likely flash offsets with confidence levels.

## Prerequisites

1. Mainline Klipper checkout exists at `~/klipper` (or set `KLIPPER_DIR`).
2. Katapult checkout exists at `~/katapult` (or set `KATAPULT_DIR`).
3. CAN interface is up (default: `can0`).
4. Exact imported profile sets are present:
  - Firmware: `config/mcu-firmware-configurations/`
  - Bootloader: `config/mcu-bootloader-configurations/`

## One-time setup

1. Copy env example:

```sh
cp config/mcu-update.env.example config/mcu-update.env
```

2. Edit `config/mcu-update.env` and set:

- `KLIPPER_DIR`
- `MAINBOARD_UUID` (optional if present in `~/printer_data/config/canuid.cfg`)
- `TOOLHEAD_UUID` (optional if present in `~/printer_data/config/canuid.cfg`)
- optional `CAN_IFACE`

If UUIDs are omitted in `config/mcu-update.env`, `update_both_mcus.sh` will
auto-read them from `~/printer_data/config/canuid.cfg` by default.
You can override this with `--canuid-cfg /path/to/canuid.cfg`.

3. Validate profile files under these directories match your hardware:
  - `config/mcu-firmware-configurations/`
  - `config/mcu-bootloader-configurations/`

## Build Katapult bootloaders (exact profiles)

```sh
./scripts/mcu/build_katapult_bootloaders.sh
```

Output files:

- `out/bootloader/katapult_mainboard_stm32f407.bin`
- `out/bootloader/katapult_toolhead_rp2040.bin`
- `out/bootloader/katapult_toolhead_rp2040.uf2` (when produced by Katapult)

## Discover UUIDs

```sh
./scripts/mcu/discover_can_uuids.sh can0
```

## Build only

```sh
./scripts/mcu/build_klipper_mcus.sh
```

Output binaries:

- `out/mcu/klipper_mainboard.bin`
- `out/mcu/klipper_toolhead.bin`

## Flash only

```sh
./scripts/mcu/flash_klipper_mcus_katapult.sh \
  --mainboard-uuid <mainboard_uuid> \
  --toolhead-uuid <toolhead_uuid>
```

## Request bootloader only (no flash)

Single UUID:

```sh
./scripts/mcu/request_bootloader_and_query.sh \
  --uuid <uuid> \
  --python-bin /home/mks/klippy-env/bin/python
```

Both UUIDs from env file:

```sh
./scripts/mcu/request_bootloader_and_query.sh \
  --env-file config/mcu-update.env \
  --python-bin /home/mks/klippy-env/bin/python
```

If a UUID does not appear in query output after `-r`, that MCU likely was not in a state where Klipper could hand off to Katapult.

## Build + flash (recommended)

```sh
./scripts/mcu/update_both_mcus.sh --env-file config/mcu-update.env
```

To also write a local `config/local/canuid.cfg` with the provided UUIDs:

```sh
./scripts/mcu/update_both_mcus.sh --env-file config/mcu-update.env --update-canuid-cfg
```

## Notes

- Flash helpers require `~/katapult/scripts/flashtool.py`.
- The default MCU and bootloader profiles are the exact imported X400 profiles.

## Infer offsets from reference snapshot (no SWD)

If you captured a stock printer mirror under `reference/printer-home`, run:

```sh
python3 ./scripts/mcu/report_reference_offsets.py
```

Optional custom path:

```sh
python3 ./scripts/mcu/report_reference_offsets.py --reference-root /path/to/printer-home
```

This is useful for narrowing candidate offsets before flashing. Treat low-confidence BIN results as hints only.
