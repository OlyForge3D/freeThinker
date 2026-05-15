# Upstream baseline selection (Phase 1)

This project vendors no upstream source trees, but the legacy
`thinker400_klipperscreen` repo did. To inventory and migrate those changes we
need a reproducible upstream comparison point per component.

## Legacy provenance anchor

- **Legacy repo:** `jpapiez/thinker400_klipperscreen`
- **Root import commit:** `1ba5fc27d2691074a0147a914b792d107ab056fe`
- **Root import timestamp:** `2025-06-02T17:27:32+08:00`

## Baselines used

| Component | Upstream repo | Branch | Baseline SHA | Commit date | Confidence |
|-----------|---------------|--------|--------------|-------------|------------|
| KlipperScreen | `KlipperScreen/KlipperScreen` | `master` | `2397a44` | 2025-05-25 | High |
| Klipper | `Klipper3d/klipper` | `master` | `cfa48fe3` | 2025-05-31 | Medium |
| Moonraker | `Arksine/moonraker` | `master` | `0310d0b` | 2025-05-22 | Medium |
| moonraker-timelapse | `mainsail-crew/moonraker-timelapse` | `main` | `c7fff11` | 2023-12-16 | Medium |

## Selection method

1. Clone each upstream repository.
2. Resolve the default upstream branch (`origin/HEAD`).
3. Pick the latest upstream commit **before** the legacy root-import timestamp.
4. Compare file blob hashes for runtime paths (component-specific focus paths).

This method is deterministic and good enough for migration planning, even if
the vendored snapshot was not imported from the exact prior commit.

## Why confidence differs

- **KlipperScreen (High):** the legacy repo history clearly tracks a
  KlipperScreen fork/merge workflow, so date-proximity aligns closely.
- **Klipper/Moonraker/Timelapse (Medium):** these were vendored snapshots
  copied into a non-native history; date-based matching is reliable for
  inventory but may not be exact source-of-truth ancestry.

## Migration policy

The purpose of these baselines is **inventory**, not permanent pinning.
Implementation work rebases on modern upstream and ports only A/B categorized
X400 behavior as plugins/overlays.

## moonraker-timelapse delta summary

Legacy root vs baseline (`c7fff11`) in focused paths:

| same | modified | added | missing |
|------|----------|-------|---------|
| 3    | 2        | 0     | 0       |

Modified files:

1. `component/timelapse.py`
2. `scripts/install.sh`

Current legacy head has no additional net changes in `moonraker-timelapse/`
after root import. Migration path: treat timelapse changes as installer/config
integration work unless the modified component behavior is still required.
