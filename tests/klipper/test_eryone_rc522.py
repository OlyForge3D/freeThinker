from __future__ import annotations

import importlib.util
from pathlib import Path


def _load_module():
    path = (
        Path(__file__).resolve().parents[2]
        / "klipper-eryone"
        / "extras"
        / "eryone_rc522.py"
    )
    spec = importlib.util.spec_from_file_location("eryone_rc522", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_extract_data_finds_marker():
    mod = _load_module()
    payload = "....en~ERYONE-PLA--FF00FF-FF-190-230-60-175-1000-2602~...."
    assert (
        mod.EryoneRC522.extract_data(payload)
        == "~ERYONE-PLA--FF00FF-FF-190-230-60-175-1000-2602~"
    )


def test_parse_rfid_string_success():
    mod = _load_module()
    parsed = mod.EryoneRC522.parse_rfid_string(
        "~ERYONE-PLA--FF00FF-FF-190-230-60-175-1000-2602~",
        extruder=1,
    )
    assert parsed is not None
    assert parsed["manufacturer"] == "ERYONE"
    assert parsed["material_name"] == "PLA"
    assert parsed["color_hex"] == "#FF00FF"
    assert parsed["extruder"] == 1


def test_parse_rfid_string_rejects_invalid():
    mod = _load_module()
    assert mod.EryoneRC522.parse_rfid_string("NOT_A_TAG", extruder=0) is None
