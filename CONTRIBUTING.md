# Contributing

Thanks for your interest in improving the Thinker X400 overlay.

## Ground rules

1. **No upstream forks.** Eryone-specific behavior must live in this
   repository as klippy extras, Moonraker components, KlipperScreen panels,
   or installer logic. If a change genuinely cannot be expressed that way,
   the preferred order is:
   1. Open a PR against the relevant upstream project.
   2. Ship the change as a `quilt`-style patch under
      `klipper-eryone/patches/` (or analog) with a recorded upstream SHA
      and rationale.
2. **No hard-coded paths, users, or passwords** in installer scripts.
   Everything must be discovered at install time.
3. **Idempotent installer steps.** Re-running `install.sh` must converge
   without error.
4. **License hygiene.** Code added under `klipperscreen-eryone/` is
   AGPL-3.0; everywhere else is GPL-3.0. See [`LICENSING.md`](LICENSING.md).

## Development

- Lint everything before opening a PR:
   - `shellcheck` on shell scripts under `installer/` and `config/printer/scripts/`.
  - `ruff check` on Python under `klipper-eryone/`, `moonraker-eryone/`,
    `klipperscreen-eryone/`.
- Run unit tests with `pytest` (subdirectory READMEs explain mocking
  klippy / moonraker).
- Run installer tests with `bats tests/installer/`.

### Shell script header convention

All tracked `.sh` scripts should include this header block immediately after
the shebang:

```sh
# File: <repo-relative-path>
# Purpose: <one-line description of behavior and scope>
#
```

Keep `Purpose` concrete and operational, especially for scripts that change
printer state, rewrite config, or flash firmware.

## Commit messages

Conventional Commits encouraged but not enforced:

```
feat(installer): add x400_300 variant
fix(klipper-eryone): handle rc522 read timeout
docs: clarify hardware matrix
```

## Reporting issues

Please include:

- MainsailOS version (`cat /etc/mainsailos-release` if present, otherwise
  `cat /etc/os-release`).
- Output of `installer/lib/preflight.sh --report` (once it exists).
- Klipper, Moonraker, KlipperScreen versions.
- Hardware variant.
