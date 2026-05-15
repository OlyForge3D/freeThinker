"""Eryone Moonraker file-manager overlay.

This component replaces the legacy hard-coded upload temp path patch in
`file_manager.py` with a runtime-configurable override.
"""

from __future__ import annotations

import logging
import os
import pathlib
from typing import TYPE_CHECKING, Callable

if TYPE_CHECKING:
    from moonraker.confighelper import ConfigHelper
    from moonraker.components.file_manager.file_manager import FileManager


class EryoneFileManagerOverlay:
    def __init__(self, config: "ConfigHelper") -> None:
        self.server = config.get_server()
        self.config = config
        self._orig_gen_temp_upload_path: Callable[[], str] | None = None

    def _resolve_upload_root(self) -> pathlib.Path:
        configured = self.config.get("upload_tmp_root", None)
        if configured:
            root = pathlib.Path(configured).expanduser().resolve()
        else:
            root = pathlib.Path.home() / "printer_data" / "gcodes"
        root.mkdir(parents=True, exist_ok=True)
        return root

    def component_init(self) -> None:
        fm: "FileManager" = self.server.lookup_component("file_manager")
        if self._orig_gen_temp_upload_path is not None:
            return
        self._orig_gen_temp_upload_path = fm.gen_temp_upload_path
        upload_root = self._resolve_upload_root()

        def _patched_gen_temp_upload_path() -> str:
            loop_time = int(fm.event_loop.get_loop_time())
            return os.path.join(upload_root.as_posix(), f"moonraker.upload-{loop_time}.mru")

        fm.gen_temp_upload_path = _patched_gen_temp_upload_path
        logging.info(
            "eryone_file_manager: patched file_manager.gen_temp_upload_path -> %s",
            upload_root,
        )


def load_component(config: "ConfigHelper") -> EryoneFileManagerOverlay:
    return EryoneFileManagerOverlay(config)
