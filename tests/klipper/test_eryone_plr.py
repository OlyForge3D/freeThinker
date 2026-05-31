from __future__ import annotations

import importlib.util
from pathlib import Path


def _load_module():
    path = (
        Path(__file__).resolve().parents[2]
        / "klipper-eryone"
        / "extras"
        / "eryone_plr.py"
    )
    spec = importlib.util.spec_from_file_location("eryone_plr", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class _FakeGcode:
    def __init__(self) -> None:
        self.commands = {"SDCARD_PRINT_FILE": lambda _gcmd: None}
        self.script_lines: list[str] = []

    def register_command(self, name, cb, desc=None):
        _ = desc
        previous = self.commands.get(name)
        if cb is None:
            return previous
        self.commands[name] = cb
        return previous

    def run_script_from_command(self, line: str) -> None:
        self.script_lines.append(line)


class _FakeVirtualSD:
    def __init__(self) -> None:
        self.work_timer = None
        self.file_size = 1000
        self.file_position = 0
        self.loaded_filename = None
        self.did_resume = False

    def _reset_file(self):
        self.file_position = 0
        self.loaded_filename = None

    def _load_file(self, _gcmd, filename: str, check_subdirs: bool = True):
        _ = check_subdirs
        self.loaded_filename = filename

    def do_resume(self):
        self.did_resume = True


class _FakePrinter:
    def __init__(self, gcode: _FakeGcode, v_sd: _FakeVirtualSD) -> None:
        self.gcode = gcode
        self.v_sd = v_sd
        self.events: dict[str, object] = {}

    def lookup_object(self, name: str, default=None):
        if name == "gcode":
            return self.gcode
        if name == "virtual_sdcard":
            return self.v_sd
        return default

    def register_event_handler(self, event: str, cb):
        self.events[event] = cb

    @staticmethod
    def config_error(msg: str):
        return RuntimeError(msg)

    @staticmethod
    def command_error(msg: str):
        return RuntimeError(msg)


class _FakeConfig:
    def __init__(
        self, printer: _FakePrinter, pose_file: Path, script_file: Path
    ) -> None:
        self.printer = printer
        self.pose_file = pose_file
        self.script_file = script_file

    def get_printer(self):
        return self.printer

    def get(self, key: str, default=None):
        if key == "pose_file":
            return str(self.pose_file)
        if key == "resume_script_file":
            return str(self.script_file)
        return default


class _FakeGcmd:
    def __init__(self, filename: str, z_marker: str | None = None) -> None:
        self.filename = filename
        self.z_marker = z_marker
        self.info: list[str] = []

    def get(self, key: str, default=None):
        if key == "FILENAME":
            return self.filename
        if key == "Z":
            return self.z_marker if self.z_marker is not None else default
        return default

    def respond_info(self, msg: str):
        self.info.append(msg)

    @staticmethod
    def error(msg: str):
        return RuntimeError(msg)


def test_plr_wrapper_installs_on_ready(tmp_path):
    mod = _load_module()
    gcode = _FakeGcode()
    v_sd = _FakeVirtualSD()
    printer = _FakePrinter(gcode, v_sd)
    cfg = _FakeConfig(printer, tmp_path / "pose", tmp_path / "resume.gcode")
    plr = mod.EryonePLR(cfg)
    plr._handle_ready()
    assert gcode.commands["SDCARD_PRINT_FILE"] == plr.cmd_SDCARD_PRINT_FILE


def test_plr_resume_loads_pose_and_script(tmp_path):
    mod = _load_module()
    gcode = _FakeGcode()
    v_sd = _FakeVirtualSD()
    printer = _FakePrinter(gcode, v_sd)

    pose_file = tmp_path / "pose"
    pose_file.write_text("123\n", encoding="utf-8")
    resume_script = tmp_path / "resume.gcode"
    resume_script.write_text("G1 X10 Y10\n#comment\nM104 S200\n", encoding="utf-8")

    cfg = _FakeConfig(printer, pose_file, resume_script)
    plr = mod.EryonePLR(cfg)
    plr._handle_ready()
    gcmd = _FakeGcmd(filename="/test.gcode", z_marker="1")
    plr.cmd_SDCARD_PRINT_FILE(gcmd)

    assert v_sd.loaded_filename == "test.gcode"
    assert v_sd.file_position == 123
    assert v_sd.did_resume is True
    assert gcode.script_lines == ["G1 X10 Y10", "M104 S200"]
    assert any("resuming from byte position 123" in msg for msg in gcmd.info)
