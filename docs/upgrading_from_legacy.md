# Upgrading from the legacy `thinker400_klipperscreen` install

> **Status:** placeholder. The migration script will be implemented in
> Phase 8.

If your printer is running Eryone's stock image (the one that puts
everything under `/home/mks/...` and runs `all/relink_conf.sh` at boot),
this page will describe how to migrate to the clean overlay.

Planned outline:

1. **Backup.** The migration script will snapshot
   `~/printer_data/config/`, `~/klipper`, `~/moonraker`, and
   `~/KlipperScreen` to a timestamped tarball.
2. **Detect legacy state.** Look for `relink_conf.sh`, `cloud_mq.service`,
   the hard-coded `mks` user, and the `Bed_D*` sentinel directories.
3. **Disable legacy hooks.** Remove the `relink_conf.sh` invocation from
   `/etc/rc.local`, disable `cloud_mq.service` if undesired, restore any
   files Eryone copied over upstream installs.
4. **Reinstall upstream.** Reinstall Klipper, Moonraker, KlipperScreen
   from their official sources at the SHAs this overlay is tested against.
5. **Run `./install.sh`.** Apply the clean overlay.
