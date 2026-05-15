"""Eryone RC522 RFID reader integration for Klipper.

This module is extracted from the legacy Thinker X400 fork and namespaced as
an out-of-tree extra so upstream Klipper sources remain untouched.
"""

import json
import re
import threading
import time
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional

try:
    from . import bus
except ImportError:
    # Allows standalone import in unit tests where klippy package layout
    # is not present. Runtime Klipper installations always resolve this.
    bus = None


class EryoneRC522:
    CommandReg = 0x01
    ComIrqReg = 0x04
    DivIrqReg = 0x05
    ErrorReg = 0x06
    FIFODataReg = 0x09
    FIFOLevelReg = 0x0A
    BitFramingReg = 0x0D
    ModeReg = 0x11
    TxControlReg = 0x14
    TxASKReg = 0x15
    CRCResultRegH = 0x21
    CRCResultRegL = 0x22
    TModeReg = 0x2A
    TPrescalerReg = 0x2B
    TReloadRegH = 0x2C
    TReloadRegL = 0x2D

    PCD_IDLE = 0x00
    PCD_CALC_CRC = 0x03
    PCD_TRANSCEIVE = 0x0C
    PCD_SOFT_RESET = 0x0F

    def __init__(self, config):
        self.printer = config.get_printer()
        self.reactor = self.printer.get_reactor()
        self.gcode = self.printer.lookup_object("gcode")
        if bus is None:
            raise config.error("eryone_rc522 requires Klipper runtime (bus module unavailable)")

        # The legacy config used decimal 40 (0x28) as default.
        address = config.getint("address", 40)
        speed = config.getint("speed", 100000)
        self.i2c = bus.MCU_I2C_from_config(config, address, speed)

        self.moonraker_host = config.get("moonraker_host", "127.0.0.1")
        self.moonraker_port = config.getint("moonraker_port", 7125)
        self.scan_timeout = config.getfloat("scan_timeout", 5.0, minval=0.1)

        self.last_uid: Optional[List[int]] = None
        self.last_parsed_data: Optional[str] = None
        self.scan_timer = None
        self.scan_end_time = 0.0
        self.scan_extruder = 1
        self.auto_save = False

        self.gcode.register_command("M410", self.cmd_m410)
        self.printer.register_event_handler("klippy:ready", self._handle_ready)

    # ---------------- I2C primitives ----------------
    def write_reg(self, reg: int, val: int) -> None:
        self.i2c.i2c_write([reg, val])

    def read_reg(self, reg: int) -> int:
        params = self.i2c.i2c_read([reg], 1)
        return params["response"][0]

    def set_bit_mask(self, reg: int, mask: int) -> None:
        self.write_reg(reg, self.read_reg(reg) | mask)

    def clear_bit_mask(self, reg: int, mask: int) -> None:
        self.write_reg(reg, self.read_reg(reg) & (~mask))

    # ---------------- RC522 init ----------------
    def _handle_ready(self) -> None:
        self.init_rc522()

    def init_rc522(self) -> None:
        self.write_reg(self.CommandReg, self.PCD_SOFT_RESET)
        time.sleep(0.1)
        self.write_reg(self.TModeReg, 0x8D)
        self.write_reg(self.TPrescalerReg, 0x3E)
        self.write_reg(self.TReloadRegL, 30)
        self.write_reg(self.TReloadRegH, 0)
        self.write_reg(self.TxASKReg, 0x40)
        self.write_reg(self.ModeReg, 0x3D)
        self.antenna_on()

    def antenna_on(self) -> None:
        if not (self.read_reg(self.TxControlReg) & 0x03):
            self.set_bit_mask(self.TxControlReg, 0x03)

    # ---------------- Card comms ----------------
    def transceive(self, send_data: List[int]) -> Optional[List[int]]:
        self.write_reg(self.CommandReg, self.PCD_IDLE)
        self.write_reg(self.ComIrqReg, 0x7F)
        self.write_reg(self.FIFOLevelReg, 0x80)
        for b in send_data:
            self.write_reg(self.FIFODataReg, b)
        self.write_reg(self.CommandReg, self.PCD_TRANSCEIVE)
        self.set_bit_mask(self.BitFramingReg, 0x80)

        timeout = 2000
        while timeout:
            irq = self.read_reg(self.ComIrqReg)
            if irq & 0x20:
                break
            if irq & 0x01:
                return None
            timeout -= 1
        if not timeout:
            return None

        self.clear_bit_mask(self.BitFramingReg, 0x80)
        if self.read_reg(self.ErrorReg) & 0x1B:
            return None

        count = self.read_reg(self.FIFOLevelReg)
        if count == 0:
            return None
        return [self.read_reg(self.FIFODataReg) for _ in range(count)]

    def request(self) -> Optional[List[int]]:
        self.write_reg(self.BitFramingReg, 0x07)
        result = self.transceive([0x26])
        self.write_reg(self.BitFramingReg, 0x00)
        return result if result and len(result) == 2 else None

    def anticoll(self, cmd: int) -> Optional[List[int]]:
        self.write_reg(self.BitFramingReg, 0x00)
        return self.transceive([cmd, 0x20])

    def calculate_crc(self, data: List[int]) -> List[int]:
        self.write_reg(self.CommandReg, self.PCD_IDLE)
        self.write_reg(self.DivIrqReg, 0x04)
        self.write_reg(self.FIFOLevelReg, 0x80)
        for b in data:
            self.write_reg(self.FIFODataReg, b)
        self.write_reg(self.CommandReg, self.PCD_CALC_CRC)
        for _ in range(1000):
            if self.read_reg(self.DivIrqReg) & 0x04:
                break
        return [self.read_reg(self.CRCResultRegL), self.read_reg(self.CRCResultRegH)]

    def select(self, cmd: int, uid_block: List[int]) -> Optional[List[int]]:
        buf = [cmd, 0x70] + uid_block[:5]
        buf += self.calculate_crc(buf)
        return self.transceive(buf)

    def get_uid(self) -> Optional[List[int]]:
        cl1 = self.anticoll(0x93)
        if not cl1 or len(cl1) < 5:
            return None
        self.select(0x93, cl1)
        if cl1[0] != 0x88:
            return cl1[:4]
        uid_part1 = cl1[1:4]
        cl2 = self.anticoll(0x95)
        if not cl2 or len(cl2) < 5:
            return None
        self.select(0x95, cl2)
        return uid_part1 + cl2[:4]

    def read_page(self, page: int) -> Optional[List[int]]:
        self.write_reg(self.BitFramingReg, 0x00)
        payload = [0x30, page]
        payload += self.calculate_crc(payload)
        result = self.transceive(payload)
        return result[:16] if result and len(result) >= 16 else None

    def read_all_user_pages(self) -> Optional[List[int]]:
        data: List[int] = []
        for page in range(4, 40, 4):
            block = self.read_page(page)
            if not block:
                return None
            data.extend(block)
        return data

    # ---------------- Parse helpers ----------------
    @staticmethod
    def extract_data(raw_ascii: str) -> Optional[str]:
        marker = "en~"
        pos = raw_ascii.find(marker)
        if pos < 0:
            return None
        start = pos + 2
        end = raw_ascii.rfind("~")
        if end <= start:
            return None
        return raw_ascii[start : end + 1]

    @staticmethod
    def _parse_int(value: str, base: int = 10, fallback: int = 0) -> int:
        try:
            return int(value, base) if value else fallback
        except (TypeError, ValueError):
            return fallback

    @classmethod
    def parse_rfid_string(cls, data_str: str, extruder: int) -> Optional[Dict[str, Any]]:
        if not data_str.startswith("~"):
            return None
        parts = data_str[1:].split("-")
        if len(parts) < 11:
            return None

        manufacturer = parts[0].strip()
        material_name = parts[1].strip()
        material_supplement = parts[2].strip()
        color_hex = parts[3].strip()
        if color_hex and not color_hex.startswith("#"):
            color_hex = f"#{color_hex}"
        if len(color_hex) != 7:
            color_hex = "#808080"

        try:
            color_rgb = [int(color_hex[i : i + 2], 16) for i in (1, 3, 5)]
        except ValueError:
            color_hex = "#808080"
            color_rgb = [128, 128, 128]

        min_temp = cls._parse_int(parts[5].strip(), fallback=0)
        max_temp = cls._parse_int(parts[6].strip(), fallback=0)
        bed_temp = cls._parse_int(parts[7].strip(), fallback=0)
        weight = cls._parse_int(parts[9].strip(), fallback=0)
        production_date = cls._parse_int(parts[10].strip(), fallback=0)
        transparency = cls._parse_int(parts[4].strip(), base=16, fallback=255)
        diameter_raw = cls._parse_int(parts[8].strip(), fallback=175)
        diameter = diameter_raw / 100.0

        return {
            "manufacturer": manufacturer,
            "material_name": material_name,
            "material_supplement": material_supplement,
            "color_hex": color_hex,
            "color_rgb": color_rgb,
            "transparency": transparency,
            "min_temp": min_temp,
            "max_temp": max_temp,
            "bed_temp": bed_temp,
            "diameter": diameter,
            "weight": weight,
            "production_date": production_date,
            "date_string": str(production_date) if production_date else "",
            "extruder": extruder,
        }

    # ---------------- Moonraker persistence ----------------
    def _save_parsed_to_moonraker(self, parsed: Dict[str, Any], extruder: int) -> None:
        def _run() -> None:
            url = f"http://{self.moonraker_host}:{self.moonraker_port}/server/database/item"
            payload = {
                "namespace": "rfid_tags",
                "key": f"extruder_{extruder}",
                "value": parsed,
            }
            request = urllib.request.Request(
                url=url,
                data=json.dumps(payload).encode("utf-8"),
                method="POST",
                headers={"Content-Type": "application/json"},
            )
            try:
                with urllib.request.urlopen(request, timeout=5) as response:
                    self.gcode.respond_info(f"RFID data saved (HTTP {response.getcode()})")
            except (urllib.error.URLError, TimeoutError, OSError) as exc:
                self.gcode.respond_info(f"RFID save failed: {exc}")

        t = threading.Thread(target=_run, daemon=True)
        t.start()

    # ---------------- Scan loop ----------------
    def _scan_loop(self, eventtime: float):
        if eventtime >= self.scan_end_time:
            self.scan_timer = None
            self.gcode.respond_info("RFID scan finished (timeout)")
            return self.reactor.NEVER

        if not self.request():
            return eventtime + 0.1

        uid = self.get_uid()
        if not uid or uid == self.last_uid:
            return eventtime + 0.1
        self.last_uid = uid

        user_data = self.read_all_user_pages()
        if not user_data:
            return eventtime + 0.1

        ascii_data = "".join(chr(b) if 32 <= b <= 126 else "." for b in user_data)
        parsed_blob = self.extract_data(ascii_data)
        if not parsed_blob:
            return eventtime + 0.1

        self.last_parsed_data = parsed_blob
        self.gcode.respond_info(f"RFID parsed: {parsed_blob}")
        if self.auto_save:
            parsed = self.parse_rfid_string(parsed_blob, self.scan_extruder)
            if parsed is None:
                self.gcode.respond_info("RFID parse failed, not saving")
            else:
                self._save_parsed_to_moonraker(parsed, self.scan_extruder)

        self.reactor.unregister_timer(self.scan_timer)
        self.scan_timer = None
        return self.reactor.NEVER

    # ---------------- GCode entry ----------------
    def cmd_m410(self, gcmd):
        if self.scan_timer is not None:
            raise gcmd.error("RFID scan already running")

        extruder_raw = gcmd.get("EXTRUDER", "1")
        save_raw = gcmd.get("SAVE", "0")
        extr_match = re.search(r"\d+", extruder_raw)
        save_match = re.search(r"\d+", save_raw)
        self.scan_extruder = int(extr_match.group()) if extr_match else 1
        self.auto_save = bool(int(save_match.group())) if save_match else False

        self.last_uid = None
        self.scan_end_time = self.reactor.monotonic() + self.scan_timeout
        self.scan_timer = self.reactor.register_timer(
            self._scan_loop, self.reactor.monotonic()
        )
        self.gcode.respond_info(
            f"RFID scan started (EXTRUDER={self.scan_extruder}, SAVE={int(self.auto_save)})"
        )


def load_config(config):
    return EryoneRC522(config)


def load_config_prefix(config):
    return EryoneRC522(config)
