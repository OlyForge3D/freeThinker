import logging
import os
import re
import subprocess

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk, Pango
from ks_includes.screen_panel import ScreenPanel

logging.getLogger(__name__).setLevel(logging.INFO)

CONFIG_DIR = os.path.join(os.path.expanduser("~"), "printer_data", "config")
PRINTER_CFG_PATH = os.path.join(CONFIG_DIR, "printer.cfg")

DRIVE_MODE_CONFIGS = {
    "standard": "v1_1.cfg",
    "performance": "v1_2.cfg",
}

class Panel(ScreenPanel):
    def __init__(self, screen, title):
        super().__init__(screen, title)

        grid_columns = 3
        button_spacing = 25

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        main_box.set_halign(Gtk.Align.CENTER)
        main_box.set_valign(Gtk.Align.CENTER)
        main_box.set_hexpand(True)
        main_box.set_vexpand(True)

        self.current_drive_mode_label = self._gtk.Label(_("Current Drive Mode: Unknown"))
        self.current_drive_mode_label.set_halign(Gtk.Align.CENTER)
        self.current_probe_count_label = self._gtk.Label(_("Current Grid Size: N/A"))
        self.current_probe_count_label.set_halign(Gtk.Align.CENTER)

        mode_title_label = self._gtk.Label(_("Select Drive Mode"), "title")
        mode_title_label.set_halign(Gtk.Align.CENTER)

        self.mode_buttons = {
            "standard": self._gtk.Button(
                "settings", _("Standard"), "color3", self.bts, Gtk.PositionType.LEFT, 1
            ),
            "performance": self._gtk.Button(
                "flash", _("Performance"), "color1", self.bts, Gtk.PositionType.LEFT, 1
            ),
        }
        mode_grid = Gtk.Grid()
        mode_grid.set_column_spacing(button_spacing)
        mode_grid.set_row_spacing(button_spacing)
        mode_grid.set_halign(Gtk.Align.CENTER)
        mode_grid.set_column_homogeneous(True)
        mode_grid.set_row_homogeneous(True)

        for index, (mode_key, button) in enumerate(self.mode_buttons.items()):
            button.set_hexpand(True)
            button.connect("clicked", self._confirm_drive_mode_change, mode_key)
            mode_grid.attach(button, index, 0, 1, 1)

        title_label = self._gtk.Label(_("Select Bed Mesh Grid Size"), "title")
        title_label.set_halign(Gtk.Align.CENTER)

        grid = Gtk.Grid()
        grid.set_column_spacing(button_spacing)
        grid.set_row_spacing(button_spacing)
        grid.set_halign(Gtk.Align.CENTER)
        grid.set_column_homogeneous(True)
        grid.set_row_homogeneous(True)

        buttons_data = [
            ("3x3", "color3"),
            ("4x4", "color4"),
            ("5x5", "color1"),
            ("6x6", "color2"),
            ("7x7", "color3"),
            ("8x8", "color4"),
            ("9x9", "color1"),
            ("10x10", "color2"),
        ]

        for index, (grid_size, color) in enumerate(buttons_data):
            button = self._gtk.Button(
                "adjust", _(f"{grid_size} Grid"), color, self.bts, Gtk.PositionType.LEFT, 1
            )
            button.set_hexpand(True)
            button.connect("clicked", self._confirm_probe_count_change, grid_size)

            col = index % grid_columns
            row = index // grid_columns
            grid.attach(button, col, row, 1, 1)

        main_box.pack_start(self.current_drive_mode_label, False, False, 0)
        main_box.pack_start(mode_title_label, False, False, 0)
        main_box.pack_start(mode_grid, False, False, 0)
        main_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 0)
        main_box.pack_start(self.current_probe_count_label, False, False, 0)
        main_box.pack_start(title_label, False, False, 0)
        main_box.pack_start(grid, False, False, 0)

        self.content.add(main_box)
        self._update_drive_mode_ui()
        self._update_grid_size_label()

    def _get_mode_display_name(self, mode_key):
        if mode_key == "standard":
            return _("Standard")
        if mode_key == "performance":
            return _("Performance")
        return _("Unknown")

    def _get_active_drive_mode(self):
        try:
            with open(PRINTER_CFG_PATH, "r", encoding="utf-8") as fh:
                for line in fh:
                    stripped = line.strip()
                    if stripped == f"[include {DRIVE_MODE_CONFIGS['standard']}]":
                        return "standard"
                    if stripped == f"[include {DRIVE_MODE_CONFIGS['performance']}]":
                        return "performance"
        except OSError as err:
            logging.error("Unable to read printer.cfg at %s: %s", PRINTER_CFG_PATH, err)
            return None
        return None

    def _update_drive_mode_ui(self):
        mode_key = self._get_active_drive_mode()
        mode_name = self._get_mode_display_name(mode_key)
        self.current_drive_mode_label.set_text(
            _("Current Drive Mode: {mode}").format(mode=mode_name)
        )
        for key, button in self.mode_buttons.items():
            if key == mode_key:
                button.get_style_context().add_class("button_active")
            else:
                button.get_style_context().remove_class("button_active")

    def _confirm_drive_mode_change(self, widget, mode_key):
        mode_name = self._get_mode_display_name(mode_key)
        text = _(
            "Switch to {mode} mode?\n\nKlipper will automatically restart after confirmation"
        ).format(mode=mode_name)

        buttons = [
            {"name": _("Confirm"), "response": Gtk.ResponseType.OK},
            {"name": _("Cancel"), "response": Gtk.ResponseType.CANCEL},
        ]

        label = Gtk.Label()
        label.set_markup(text)
        label.set_hexpand(True)
        label.set_halign(Gtk.Align.CENTER)
        label.set_vexpand(True)
        label.set_valign(Gtk.Align.CENTER)
        label.set_line_wrap(True)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)

        self.confirm_dialog = self._gtk.Dialog(
            self._screen, buttons, label, self._on_drive_mode_confirm_response, mode_key
        )
        self.confirm_dialog.set_title(_("Change Drive Mode"))

    def _on_drive_mode_confirm_response(self, dialog, response_id, mode_key):
        self._gtk.remove_dialog(dialog)
        if response_id == Gtk.ResponseType.OK:
            self._update_drive_mode(mode_key)

    def _update_drive_mode(self, mode_key):
        target_cfg = DRIVE_MODE_CONFIGS.get(mode_key)
        if target_cfg is None:
            self._screen.show_popup_message(_("Error: Invalid drive mode"), level=2, timeout=5)
            return

        active_mode = self._get_active_drive_mode()
        if active_mode == mode_key:
            self._screen.show_popup_message(
                _("Drive mode is already set to {mode}").format(
                    mode=self._get_mode_display_name(mode_key)
                ),
                level=1,
                timeout=3,
            )
            return

        target_cfg_path = os.path.join(CONFIG_DIR, target_cfg)
        if not os.path.exists(target_cfg_path):
            self._screen.show_popup_message(
                _("Error: Missing {cfg}").format(cfg=target_cfg), level=2, timeout=5
            )
            return

        try:
            with open(PRINTER_CFG_PATH, "r", encoding="utf-8") as fh:
                printer_cfg = fh.read()
            updated_cfg, replacements = re.subn(
                r"^\[include\s+v1_[12]\.cfg\]\s*$",
                f"[include {target_cfg}]",
                printer_cfg,
                count=1,
                flags=re.MULTILINE,
            )
            if replacements == 0:
                self._screen.show_popup_message(
                    _("Error: Could not find v1 include line in printer.cfg"),
                    level=2,
                    timeout=5,
                )
                return
            with open(PRINTER_CFG_PATH, "w", encoding="utf-8") as fh:
                fh.write(updated_cfg)
            subprocess.run(["sync"], check=False)
        except OSError as err:
            logging.error("Failed to update drive mode in %s: %s", PRINTER_CFG_PATH, err)
            self._screen.show_popup_message(_("Error: Failed to update printer.cfg"), level=2, timeout=5)
            return

        self._update_drive_mode_ui()
        self._screen.show_popup_message(
            _("Drive mode changed to '{mode}' Restarting Klipper...").format(
                mode=self._get_mode_display_name(mode_key)
            ),
            level=1,
            timeout=3,
        )
        GLib.timeout_add(1000, self._restart_klipper)

    def _update_grid_size_label(self):
        current_probe_count = self._get_current_probe_count()
        self.current_probe_count_label.set_text(
            _("Current Grid Size: {probe_count}").format(probe_count=current_probe_count)
        )

    def _confirm_probe_count_change(self, widget, grid_size):
        text = _(
            "Change grid size to {grid_size}?\n\nKlipper will automatically restart after confirmation"
        ).format(grid_size=grid_size)

        buttons = [
            {"name": _("Confirm"), "response": Gtk.ResponseType.OK},
            {"name": _("Cancel"), "response": Gtk.ResponseType.CANCEL},
        ]

        label = Gtk.Label()
        label.set_markup(text)
        label.set_hexpand(True)
        label.set_halign(Gtk.Align.CENTER)
        label.set_vexpand(True)
        label.set_valign(Gtk.Align.CENTER)
        label.set_line_wrap(True)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)

        self.confirm_dialog = self._gtk.Dialog(
            self._screen, buttons, label, self._on_probe_count_confirm_response, grid_size
        )
        self.confirm_dialog.set_title(_("Change Grid Size"))

    def _on_probe_count_confirm_response(self, dialog, response_id, grid_size):
        self._gtk.remove_dialog(dialog)
        if response_id == Gtk.ResponseType.OK:
            self._update_probe_count(grid_size)

    def _get_active_config_file(self):
        try:
            with open(PRINTER_CFG_PATH, "r", encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if "[include EECAN.cfg]" in line:
                        return "EECAN.cfg"
                    if "[include EECAN1_350.cfg]" in line:
                        return "EECAN1_350.cfg"
                    if "[include EECAN1_300.cfg]" in line:
                        return "EECAN1_300.cfg"
            return None
        except FileNotFoundError:
            logging.error("Main config file not found: %s", PRINTER_CFG_PATH)
            self._screen.show_popup_message(_("Error: printer.cfg not found"), level=2, timeout=5)
            return None

    def _get_current_probe_count(self):
        target_filename = self._get_active_config_file()
        if not target_filename:
            logging.warning("Could not determine active config to read probe_count.")
            return "N/A"

        target_config_path = os.path.join(CONFIG_DIR, target_filename)
        if not os.path.exists(target_config_path):
            logging.warning("Target config file not found: %s", target_config_path)
            return "N/A"

        try:
            with open(target_config_path, "r", encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    match = re.match(r"^\s*probe_count\s*:\s*(\d+)\s*,\s*(\d+)", line)
                    if match:
                        return f"{match.group(1)}x{match.group(2)}"
            return _("Not Set")
        except OSError as err:
            logging.error("Error reading probe_count from %s: %s", target_config_path, err)
            return _("Error")

    def _update_probe_count(self, grid_size):
        target_filename = self._get_active_config_file()
        if not target_filename:
            logging.error("Could not determine the active EECAN config file from printer.cfg.")
            self._screen.show_popup_message(
                _("Error: Active config not found in printer.cfg"), level=2, timeout=5
            )
            return

        target_config_path = os.path.join(CONFIG_DIR, target_filename)

        try:
            if not os.path.exists(target_config_path):
                logging.error("Target config file does not exist: %s", target_config_path)
                self._screen.show_popup_message(
                    _("Error: Target config file does not exist"), level=2, timeout=5
                )
                return

            count = grid_size.split("x")[0]
            sed_command = f"s/^probe_count:.*/probe_count: {count}, {count}/"
            command_list = ["sed", "-i", sed_command, target_config_path]

            subprocess.run(command_list, capture_output=True, text=True, check=True)
            subprocess.run(["sync"], check=False)

            self._screen.show_popup_message(
                _("Grid size changed to '{size}' Restarting Klipper...").format(size=grid_size),
                level=1,
                timeout=3,
            )
            GLib.timeout_add(1000, self._restart_klipper)

        except subprocess.CalledProcessError as err:
            logging.error("Failed to execute sed command: %s", err.stderr)
            self._screen.show_popup_message(_("Error: Failed to update config file"), level=2, timeout=5)
        except OSError as err:
            logging.error("Unexpected filesystem error while updating probe_count: %s", err)
            self._screen.show_popup_message(_("Error: An unknown error occurred"), level=2, timeout=5)

    def _restart_klipper(self):
        logging.info("Restarting Klipper service...")

        try:
            self._screen._ws.send_method("machine.services.restart", {"service": "klipper"})
            logging.info("Klipper restart command sent via Moonraker API")
        except Exception as err:
            logging.error("Error calling Moonraker API: %s", err)
            self._screen.show_popup_message(
                _("Failed to restart Klipper through Moonraker API."), level=2, timeout=5
            )

        return False

    def activate(self):
        self._update_drive_mode_ui()
        self._update_grid_size_label()

    def on_back(self):
        self._screen.remove_panel(self)
        self._screen.update_panels()
        return True
