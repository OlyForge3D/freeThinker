# Klipper patch queue

This directory is intentionally kept for exceptional upstream hotfixes, but
the current migration target is **zero local Klipper patches**.

## Policy

1. Prefer out-of-tree extras in `../extras/` over patching upstream Klipper.
2. Keep patch count minimal and explicitly justified.
3. Pin and test against a known upstream Klipper SHA before applying.
4. Fail fast if patches do not apply cleanly.

## Current queue

No active patches.
