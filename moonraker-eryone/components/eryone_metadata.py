"""Eryone Moonraker metadata overlay.

Legacy X400 images carried a large fork of Moonraker's metadata parser. This
component keeps upstream parser behavior and only adds optional Eryone metadata
extraction from custom comment lines in gcode headers.
"""

from __future__ import annotations

import logging
import pathlib
import re
from typing import TYPE_CHECKING, Any, Callable, Dict, List

if TYPE_CHECKING:
    from moonraker.confighelper import ConfigHelper

ERYONE_HINT_RE = re.compile(r"^\s*;\s*ERYONE_(?P<key>[A-Z0-9_]+)\s*=\s*(?P<value>.+?)\s*$")

class EryoneMetadataOverlay:
    def __init__(self, config: "ConfigHelper") -> None:
        self.server = config.get_server()
        self.config = config
        self.max_scan_bytes = config.getint("hint_scan_bytes", 1024 * 1024, minval=1024)
        self._patched = False

    def _extract_eryone_hints(self, file_path: str) -> Dict[str, str]:
        path = pathlib.Path(file_path)
        hints: Dict[str, str] = {}
        if not path.is_file():
            return hints
        try:
            with path.open("r", encoding="utf-8", errors="ignore") as fh:
                data = fh.read(self.max_scan_bytes)
        except OSError as exc:
            logging.debug("eryone_metadata: failed to read %s: %s", path, exc)
            return hints
        for line in data.splitlines():
            match = ERYONE_HINT_RE.match(line)
            if match is None:
                continue
            key = match.group("key").lower()
            hints[key] = match.group("value").strip()
        return hints

    def component_init(self) -> None:
        if self._patched:
            return

        # Import here so the component can load even if Moonraker internals
        # move, and fail with a clear startup error if extraction API changed.
        from moonraker.components.file_manager import metadata as metadata_mod

        original_extract: Callable[[str, List[Dict[str, Any]]], Dict[str, Any]]
        original_extract = metadata_mod.extract_metadata

        def _patched_extract_metadata(
            file_path: str, processors: List[Dict[str, Any]]
        ) -> Dict[str, Any]:
            result = original_extract(file_path, processors)
            hints = self._extract_eryone_hints(file_path)
            if hints:
                result["eryone_hints"] = hints
            return result

        metadata_mod.extract_metadata = _patched_extract_metadata
        self._patched = True
        logging.info("eryone_metadata: patched metadata.extract_metadata")


def load_component(config: "ConfigHelper") -> EryoneMetadataOverlay:
    return EryoneMetadataOverlay(config)
