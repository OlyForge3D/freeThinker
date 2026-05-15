# Licensing

This repository is intentionally split across two GNU copyleft licenses to
remain compatible with the upstream projects it overlays.

## GPL-3.0 (repository default)

Everything in this repository is licensed under the **GNU General Public
License v3.0** unless explicitly overridden by a `LICENSE` file in a
subdirectory. The full text is in [`LICENSE`](LICENSE).

This applies in particular to:

- `klipper-eryone/` — derives from / interoperates with [Klipper], which is
  GPL-3.0.
- `moonraker-eryone/` — derives from / interoperates with [Moonraker], which
  is GPL-3.0.
- `installer/`, `config/`, `profiles/`, `docs/`, `tests/`.

## AGPL-3.0 (klipperscreen-eryone/ subtree)

The `klipperscreen-eryone/` subtree is licensed under the **GNU Affero
General Public License v3.0**, matching upstream [KlipperScreen]. Its full
text is in [`klipperscreen-eryone/LICENSE`](klipperscreen-eryone/LICENSE).

AGPL-3.0 is GPL-3.0 plus an additional clause covering network use. Any
copy, modification, or derivative work of files inside
`klipperscreen-eryone/` must be distributed under the AGPL-3.0.

## Why two licenses

GPL-3.0 and AGPL-3.0 are not bidirectionally compatible: AGPL code cannot
be relicensed to GPL, but GPL code can be combined into an AGPL work. Since
KlipperScreen is AGPL-3.0, anything that derives from it must be AGPL-3.0
too. The rest of the project (interoperating with GPL-3.0 Klipper and
Moonraker) only needs to be GPL-3.0, and we keep it that way to preserve
optional reuse outside the KlipperScreen context.

## Third-party content

- Slicer profiles under `profiles/` may include or derive from
  vendor-supplied files. Each profile retains its original license; see
  [`profiles/LICENSES.md`](profiles/LICENSES.md) when present.
- Prebuilt MCU firmware binaries shipped under
  `klipper-eryone/firmware/` are produced from GPL-3.0 sources (Klipper +
  the Eryone out-of-tree patch series). The corresponding sources are
  available in `klipper-eryone/firmware-src/` and via the upstream Klipper
  repository at the SHAs recorded in
  `klipper-eryone/firmware/MANIFEST.json`.

[Klipper]: https://github.com/Klipper3d/klipper
[Moonraker]: https://github.com/Arksine/moonraker
[KlipperScreen]: https://github.com/KlipperScreen/KlipperScreen
