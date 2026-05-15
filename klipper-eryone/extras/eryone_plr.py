"""Eryone power-loss-resume compatibility layer for VirtualSD.

This extra replaces the legacy in-tree virtual_sdcard patch by wrapping the
SDCARD_PRINT_FILE gcode command and restoring the saved byte position from a
pose file before starting print execution.
"""

from __future__ import annotations

import logging
import os
from typing import Optional


class EryonePLR:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.gcode = self.printer.lookup_object("gcode")
        self.pose_file = config.get("pose_file", "/tmp/pose")
        self.resume_script_file = config.get("resume_script_file", "/tmp/plr.gcode")
        self._installed = False
        self._original_sdcard_print_file = None
        self.printer.register_event_handler("klippy:ready", self._handle_ready)

    def _handle_ready(self):
        if self._installed:
            return
        original = self.gcode.register_command("SDCARD_PRINT_FILE", None)
        if original is None:
            raise self.printer.config_error(
                "eryone_plr: SDCARD_PRINT_FILE command not registered"
            )
        self._original_sdcard_print_file = original
        self.gcode.register_command(
            "SDCARD_PRINT_FILE",
            self.cmd_SDCARD_PRINT_FILE,
            desc="Loads a SD file and starts print with Eryone PLR support.",
        )
        self._installed = True
        logging.info("eryone_plr: installed SDCARD_PRINT_FILE wrapper")

    def _read_resume_position(self) -> int:
        if not os.path.isfile(self.pose_file):
            raise self.printer.command_error(
                f"eryone_plr: missing pose file: {self.pose_file}"
            )
        with open(self.pose_file, "r", encoding="utf-8") as fh:
            line = fh.readline().strip()
        try:
            pos = int(line)
        except ValueError as exc:
            raise self.printer.command_error(
                f"eryone_plr: invalid pose value '{line}' in {self.pose_file}"
            ) from exc
        if pos < 0:
            raise self.printer.command_error(
                f"eryone_plr: negative pose value {pos} in {self.pose_file}"
            )
        return pos

    def _run_resume_script(self):
        if not os.path.isfile(self.resume_script_file):
            raise self.printer.command_error(
                f"eryone_plr: missing resume script: {self.resume_script_file}"
            )
        with open(self.resume_script_file, "r", encoding="utf-8") as fh:
            for raw_line in fh:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                self.gcode.run_script_from_command(line)

    def cmd_SDCARD_PRINT_FILE(self, gcmd):
        v_sd = self.printer.lookup_object("virtual_sdcard", None)
        if v_sd is None:
            raise gcmd.error("eryone_plr: virtual_sdcard object not available")
        if v_sd.work_timer is not None:
            raise gcmd.error("SD busy")

        v_sd._reset_file()
        filename = gcmd.get("FILENAME")
        if filename.startswith("/"):
            filename = filename[1:]
        v_sd._load_file(gcmd, filename, check_subdirs=True)

        resume_marker: Optional[str] = gcmd.get("Z", None)
        if resume_marker is not None:
            resume_position = self._read_resume_position()
            if v_sd.file_size > 0:
                resume_position = min(resume_position, v_sd.file_size)
            v_sd.file_position = resume_position
            gcmd.respond_info(
                f"eryone_plr: resuming from byte position {resume_position}"
            )
            self._run_resume_script()

        v_sd.do_resume()


def load_config(config):
    return EryonePLR(config)


def load_config_prefix(config):
    return EryonePLR(config)
