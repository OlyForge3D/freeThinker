# Upgrading from the legacy `thinker400_klipperscreen` install

Legacy Eryone images modify upstream trees in-place and rely on
`all/relink_conf.sh`. Migrate with the sequence below.

## 1. Backup current state

Run as the printer user:

```sh
STAMP="$(date +%Y%m%d-%H%M%S)"
tar -czf "$HOME/thinker-x400-backup-${STAMP}.tar.gz" \
  "$HOME/printer_data/config" \
  "$HOME/klipper" \
  "$HOME/moonraker" \
  "$HOME/KlipperScreen"
```

## 2. Disable legacy relink hooks

```sh
sudo sed -i '/KlipperScreen\\/all\\/relink_conf\\.sh/d' /etc/rc.local
sudo systemctl disable --now cloud_mq.service || true
sudo systemctl disable --now farm3d.service || true
```

If `/etc/rc.local` has custom local content, remove only the relink line.

## 3. Restore upstream application trees

The safest route is reinstalling official Klipper, Moonraker, and
KlipperScreen on top of MainsailOS (or re-imaging with stock MainsailOS),
then copying back your printer configuration from backup.

## 4. Install thinker-x400 overlay

```sh
git clone https://github.com/jpapiez/thinker-x400.git "$HOME/thinker-x400"
cd "$HOME/thinker-x400"
./install.sh --variant x400_350 --hotend 350
```

Use `x400_300` for 300 mm beds. Set `--hotend 300` or `--hotend 350` to match
your installed hotend.

350C upgrade guide:
<https://eryonewiki.com/en/home/HotendUpgradeto350%C2%B0CAssemblyProcess>

## 5. Validate and restart

1. Confirm symlinks exist:
   - `~/klipper/klippy/extras/eryone_*.py`
   - `~/moonraker/moonraker/components/eryone_*.py`
   - `~/KlipperScreen/panels/eryone_*.py`
2. Confirm `~/printer_data/config/printer.cfg` includes the expected variant
   include (`EECAN1_300.cfg` or `EECAN1_350.cfg`).
3. Restart services if needed:

```sh
sudo systemctl restart klipper moonraker KlipperScreen.service
```
