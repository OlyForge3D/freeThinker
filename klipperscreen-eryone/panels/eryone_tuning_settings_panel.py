import logging
import gi
import os
import subprocess
import re

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Pango, GLib 
from ks_includes.screen_panel import ScreenPanel

logging.getLogger(__name__).setLevel(logging.INFO)

CONFIG_DIR = os.path.join(os.path.expanduser("~"), "printer_data", "config")
PRINTER_CFG_PATH = os.path.join(CONFIG_DIR, "printer.cfg")


class Panel(ScreenPanel):
    def __init__(self, screen, title):
        super().__init__(screen, title)
        
        GRID_COLUMNS = 3
        BUTTON_SPACING = 25
        
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        main_box.set_halign(Gtk.Align.CENTER)
        main_box.set_valign(Gtk.Align.CENTER) 
        main_box.set_hexpand(True)
        main_box.set_vexpand(True)

        current_probe_count = self._get_current_probe_count()
        current_probe_count_text = _("Current Grid Size: {probe_count}").format(probe_count=current_probe_count)
        self.current_probe_count_label = self._gtk.Label(current_probe_count_text) 
        self.current_probe_count_label.set_halign(Gtk.Align.CENTER)

        title_label = self._gtk.Label(_("Select Bed Mesh Grid Size"), "title")
        title_label.set_halign(Gtk.Align.CENTER)
        
        grid = Gtk.Grid()
        grid.set_column_spacing(BUTTON_SPACING)
        grid.set_row_spacing(BUTTON_SPACING)
        grid.set_halign(Gtk.Align.CENTER)
        grid.set_column_homogeneous(True)
        grid.set_row_homogeneous(True)

        buttons_data = [
            ("2x2", "color2"), ("3x3", "color3"), ("4x4", "color4"),
            ("5x5", "color1"), ("6x6", "color2"), ("7x7", "color3"),
            ("8x8", "color4"), ("9x9", "color1"), ("10x10", "color2"),
        ]

        for i, (grid_size, color) in enumerate(buttons_data):
            button = self._gtk.Button("adjust", _(f"{grid_size} Grid"), color, self.bts, Gtk.PositionType.LEFT, 1)
            button.set_hexpand(True)
            button.connect("clicked", self._confirm_action, grid_size)
            
            col = i % GRID_COLUMNS
            row = i // GRID_COLUMNS
            grid.attach(button, col, row, 1, 1)

        main_box.pack_start(self.current_probe_count_label, False, False, 0)
        main_box.pack_start(title_label, False, False, 0)
        main_box.pack_start(grid, False, False, 0)
        
        self.content.add(main_box)

    def _update_grid_size_label(self):
        current_probe_count = self._get_current_probe_count()
        new_text = _("Current Grid Size: {probe_count}").format(probe_count=current_probe_count)
        self.current_probe_count_label.set_text(new_text)

    def _confirm_action(self, widget, grid_size):
        text = _("Change grid size to {grid_size}?\n\nKlipper will automatically restart after confirmation").format(grid_size=grid_size)
        
        buttons = [
            {"name": _("Confirm"), "response": Gtk.ResponseType.OK},
            {"name": _("Cancel"), "response": Gtk.ResponseType.CANCEL}
        ]

        label = Gtk.Label()
        label.set_markup(text)
        label.set_hexpand(True)
        label.set_halign(Gtk.Align.CENTER)
        label.set_vexpand(True)
        label.set_valign(Gtk.Align.CENTER)
        label.set_line_wrap(True)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)

        self.confirm_dialog = self._gtk.Dialog(self._screen, buttons, label, self._on_confirm_response, grid_size)
        self.confirm_dialog.set_title(_("Change Grid Size"))

    def _on_confirm_response(self, dialog, response_id, grid_size):
        self._gtk.remove_dialog(dialog)
        if response_id == Gtk.ResponseType.OK:
            self._update_probe_count(grid_size)

    def _get_active_config_file(self):
        try:
            with open(PRINTER_CFG_PATH, 'r') as f:
                for line in f:
                    line = line.strip()
                    if "[include EECAN.cfg]" in line:    
                        return "EECAN.cfg"
                    if "[include EECAN1_350.cfg]" in line:
                        return "EECAN1_350.cfg"
                    if "[include EECAN1_300.cfg]" in line:
                        return "EECAN1_300.cfg"
            return None
        except FileNotFoundError:
            logging.error(f"Main config file not found: {PRINTER_CFG_PATH}")
            self._screen.show_popup_message(_("Error: printer.cfg not found"), level=2, timeout=5)
            return None

    def _get_current_probe_count(self):
        target_filename = self._get_active_config_file()
        if not target_filename:
            logging.warning("Could not determine active config to read probe_count.")
            return "N/A"

        target_config_path = os.path.join(CONFIG_DIR, target_filename)
        if not os.path.exists(target_config_path):
            logging.warning(f"Target config file not found: {target_config_path}")
            return "N/A"

        try:
            with open(target_config_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    match = re.match(r"^\s*probe_count\s*:\s*(\d+)\s*,\s*(\d+)", line)
                    if match:
                        count1 = match.group(1)
                        count2 = match.group(2)
                        return f"{count1}x{count2}"
            return _("Not Set")
        except Exception as e:
            logging.error(f"Error reading probe_count from {target_config_path}: {e}")
            return _("Error")

    def _update_probe_count(self, grid_size):       
        target_filename = self._get_active_config_file()
        if not target_filename:
            logging.error("Could not determine the active EECAN config file from printer.cfg.")
            self._screen.show_popup_message(_("Error: Active config not found in printer.cfg"), level=2, timeout=5)
            return
            
        target_config_path = os.path.join(CONFIG_DIR, target_filename)

        try:
            if not os.path.exists(target_config_path):
                logging.error(f"Target config file does not exist: {target_config_path}")
                self._screen.show_popup_message(_("Error: Target config file does not exist"), level=2, timeout=5)
                return

            count = grid_size.split('x')[0]
            sed_command = f"s/^probe_count:.*/probe_count: {count}, {count}/"
            command_list = ["sed", "-i", sed_command, target_config_path]
            
            subprocess.run(command_list, capture_output=True, text=True, check=True)

            subprocess.run(["sync"], check=False)
            
            # 显示重启消息
            self._screen.show_popup_message(
                _("Grid size changed to '{size}' Restarting Klipper...").format(size=grid_size),
                level=1,
                timeout=3
            )
            
            # 延迟1秒后重启Klipper
            GLib.timeout_add(1000, self._restart_klipper)

        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to execute sed command: {e.stderr}")
            self._screen.show_popup_message(_("Error: Failed to update config file"), level=2, timeout=5)
        except OSError as e:
            logging.error(f"Unexpected filesystem error while updating probe_count: {e}")
            self._screen.show_popup_message(_("Error: An unknown error occurred"), level=2, timeout=5)

    def _restart_klipper(self):
        """重启Klipper服务"""
        logging.info("Restarting Klipper service...")
        
        try:
            self._screen._ws.send_method("machine.services.restart", {"service": "klipper"})
            logging.info("Klipper restart command sent via Moonraker API")
        except Exception as e:
            logging.error(f"Error calling Moonraker API: {e}")
            self._screen.show_popup_message(
                _("Failed to restart Klipper through Moonraker API."),
                level=2,
                timeout=5
            )
        
        return False

    def activate(self):
        # 每次激活面板时更新网格大小显示
        self._update_grid_size_label()

    def on_back(self):
        self._screen.remove_panel(self)
        self._screen.update_panels()
        return True
