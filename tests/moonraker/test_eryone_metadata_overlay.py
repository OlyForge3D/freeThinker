from __future__ import annotations

import importlib.util
from pathlib import Path


class _FakeServer:
    pass


class _FakeConfig:
    def __init__(self) -> None:
        self._server = _FakeServer()

    def get_server(self):
        return self._server

    def getint(self, _name, default, minval=None):
        _ = minval
        return default


def _load_module():
    path = (
        Path(__file__).resolve().parents[2]
        / "moonraker-eryone"
        / "components"
        / "eryone_metadata.py"
    )
    spec = importlib.util.spec_from_file_location("eryone_metadata", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_extract_eryone_hints(tmp_path):
    mod = _load_module()
    cfg = _FakeConfig()
    overlay = mod.EryoneMetadataOverlay(cfg)
    gcode = tmp_path / "sample.gcode"
    gcode.write_text(
        "; ERYONE_COLOR=FF00FF\n; ERYONE_MATERIAL=PLA\nG1 X10 Y10\n",
        encoding="utf-8",
    )
    hints = overlay._extract_eryone_hints(str(gcode))
    assert hints == {"color": "FF00FF", "material": "PLA"}
