# services/

Templated systemd unit files. The installer substitutes `@USER@`,
`@PRINTER_DATA@`, and any other placeholders at install time, then drops
the rendered units into `/etc/systemd/system/` via the user's existing
sudo rights.

Service templates available:

- `farm3d.service.in`
- `cloud_mq.service.in`

Installer step `60_services.sh` installs and enables them only when
`ENABLE_OPTIONAL_SERVICES=1`.
