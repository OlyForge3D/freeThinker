# services/

Templated systemd unit files. The installer substitutes `@USER@`,
`@PRINTER_DATA@`, and any other placeholders at install time, then drops
the rendered units into `/etc/systemd/system/` via the user's existing
sudo rights.

> **Status:** scaffold. Units (`farm3d.service.in`, `cloud_mq.service.in`)
> are added in Phase 7.
