#!/usr/bin/env python3
"""Report likely MCU flash offsets from a captured reference tree.

This inspects preserved firmware artifacts (BIN/HEX/UF2) in a reference mirror
such as freeThinker/reference/printer-home and prints evidence with a confidence
rating. It is designed to reduce guesswork before flashing, but it does NOT
replace a true SWD dump when certainty is required.
"""

from __future__ import annotations

import argparse
import binascii
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


@dataclass
class Finding:
    artifact: Path
    family: str
    sp: Optional[int]
    rv: Optional[int]
    base: Optional[int]
    offset: Optional[int]
    confidence: str
    reason: str


def fmt_hex(value: Optional[int]) -> str:
    return "n/a" if value is None else f"0x{value:08x}"


def parse_bin_vector(path: Path) -> Tuple[Optional[int], Optional[int]]:
    data = path.read_bytes()
    if len(data) < 8:
        return None, None
    sp, rv = struct.unpack_from("<II", data, 0)
    return sp, rv


def parse_intel_hex(path: Path) -> Tuple[Dict[int, int], Optional[int]]:
    mem: Dict[int, int] = {}
    upper = 0
    min_addr: Optional[int] = None

    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or not line.startswith(":"):
            continue

        payload = bytes.fromhex(line[1:])
        count = payload[0]
        addr = (payload[1] << 8) | payload[2]
        rectype = payload[3]
        data = payload[4 : 4 + count]

        if rectype == 0x00:
            abs_addr = (upper << 16) | addr
            for i, b in enumerate(data):
                cur = abs_addr + i
                mem[cur] = b
                if min_addr is None or cur < min_addr:
                    min_addr = cur
        elif rectype == 0x04:
            upper = (data[0] << 8) | data[1]
        elif rectype == 0x01:
            break

    return mem, min_addr


def parse_hex_vector(path: Path) -> Tuple[Optional[int], Optional[int], Optional[int]]:
    mem, base = parse_intel_hex(path)
    if base is None:
        return None, None, None
    b = bytes(mem.get(base + i, 0) for i in range(8))
    sp, rv = struct.unpack("<II", b)
    return sp, rv, base


def parse_uf2_vectors(path: Path) -> List[Tuple[int, int, int]]:
    data = path.read_bytes()
    out: List[Tuple[int, int, int]] = []

    for i in range(0, len(data), 512):
        blk = data[i : i + 512]
        if len(blk) < 512:
            continue
        if struct.unpack_from("<I", blk, 0)[0] != 0x0A324655:
            continue
        target = struct.unpack_from("<I", blk, 12)[0]
        payload_size = struct.unpack_from("<I", blk, 16)[0]
        payload = blk[32 : 32 + payload_size]
        if len(payload) < 8:
            continue

        sp, rv = struct.unpack_from("<II", payload, 0)
        if (
            0x20000000 <= sp <= 0x20080000
            and 0x10000001 <= rv <= 0x10200000
            and (rv & 1)
        ):
            out.append((target, sp, rv))

    return out


def classify_family(rv: Optional[int]) -> str:
    if rv is None:
        return "unknown"
    if 0x08000001 <= rv <= 0x08FFFFFF:
        return "stm32"
    if 0x10000001 <= rv <= 0x10FFFFFF:
        return "rp2040"
    return "unknown"


def infer_from_bin(path: Path, sp: Optional[int], rv: Optional[int]) -> Finding:
    family = classify_family(rv)
    base = None
    offset = None
    confidence = "low"
    reason = "binary has no absolute load address metadata"

    if family == "stm32" and rv is not None:
        # Heuristic only: infer nearest 4KiB page start from reset vector.
        base = (rv & ~1) & ~0xFFF
        offset = base - 0x08000000
        reason = "heuristic from reset vector page alignment"
    elif family == "rp2040" and rv is not None:
        base = (rv & ~1) & ~0xFF
        offset = base - 0x10000000
        reason = "heuristic from reset vector alignment"

    return Finding(path, family, sp, rv, base, offset, confidence, reason)


def first_bytes_crc(path: Path, count: int = 256) -> int:
    return binascii.crc32(path.read_bytes()[:count]) & 0xFFFFFFFF


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Infer likely MCU flash offsets from reference artifacts"
    )
    parser.add_argument(
        "--reference-root",
        default="reference/printer-home",
        help="Path to reference printer-home snapshot (default: reference/printer-home)",
    )
    args = parser.parse_args()

    root = Path(args.reference_root).expanduser().resolve()
    if not root.exists():
        raise SystemExit(f"reference root not found: {root}")

    artifacts = [
        root / "klipper/out/stm407all.hex",
        root / "klipper/out/stm407all.bin",
        root / "klipper/out/klipper.bin",
        root / "klipper/out/klipper.uf2",
        root / "KlipperScreen/docs/X400_firmware/all_klipper_407.bin",
        root / "KlipperScreen/docs/X400_firmware/klipper.uf2",
    ]

    findings: List[Finding] = []

    # Parse absolute-address Intel HEX first (strongest evidence for STM32).
    hex_path = root / "klipper/out/stm407all.hex"
    hex_crc: Optional[int] = None
    hex_base: Optional[int] = None
    if hex_path.exists():
        sp, rv, base = parse_hex_vector(hex_path)
        hex_base = base
        hex_crc = first_bytes_crc(hex_path, 1024)
        findings.append(
            Finding(
                artifact=hex_path,
                family=classify_family(rv),
                sp=sp,
                rv=rv,
                base=base,
                offset=(None if base is None else base - 0x08000000),
                confidence="high",
                reason="Intel HEX encodes absolute addresses",
            )
        )

    for path in artifacts:
        if not path.exists() or path == hex_path:
            continue

        if path.suffix.lower() == ".uf2":
            vecs = parse_uf2_vectors(path)
            if not vecs:
                findings.append(
                    Finding(
                        path,
                        "rp2040",
                        None,
                        None,
                        None,
                        None,
                        "low",
                        "no vector-like UF2 payload found",
                    )
                )
                continue
            target, sp, rv = min(vecs, key=lambda t: t[0])
            findings.append(
                Finding(
                    artifact=path,
                    family="rp2040",
                    sp=sp,
                    rv=rv,
                    base=target,
                    offset=target - 0x10000000,
                    confidence="high",
                    reason="UF2 block target address is explicit",
                )
            )
            continue

        sp, rv = parse_bin_vector(path)
        f = infer_from_bin(path, sp, rv)

        # If this BIN matches a known HEX build blob, boost confidence and pin base.
        if hex_path.exists() and path.name in {"stm407all.bin", "all_klipper_407.bin"}:
            # Compare first chunk with the hex-decoded bytes for strong linkage.
            mem, base = parse_intel_hex(hex_path)
            if base is not None:
                hex_prefix = bytes(mem.get(base + i, 0) for i in range(256))
                bin_prefix = path.read_bytes()[:256]
                if bin_prefix == hex_prefix:
                    f.base = base
                    f.offset = base - 0x08000000
                    f.confidence = "high"
                    f.reason = "BIN prefix matches absolute-address HEX image"

        findings.append(f)

    print("Reference root:", root)
    print("\nLikely MCU image starts (from captured artifacts):\n")
    print(
        f"{'artifact':72} {'family':8} {'sp':10} {'rv':10} {'base':10} {'offset':10} {'conf':6}"
    )
    print("-" * 136)
    for f in findings:
        rel = f.artifact.relative_to(root)
        print(
            f"{str(rel):72} {f.family:8} {fmt_hex(f.sp):10} {fmt_hex(f.rv):10} "
            f"{fmt_hex(f.base):10} {fmt_hex(f.offset):10} {f.confidence:6}"
        )
        print(f"  reason: {f.reason}")

    print("\nInterpretation:")
    print(
        "- high confidence means the file format embeds absolute target addresses (HEX/UF2)"
    )
    print(
        "- low confidence BIN offsets are heuristics; confirm on hardware before flashing"
    )

    # Key rollup for this printer class.
    rp = [f for f in findings if f.family == "rp2040" and f.base is not None]
    st = [f for f in findings if f.family == "stm32" and f.base is not None]

    if rp:
        b = min(f.base for f in rp if f.base is not None)
        off = b - 0x10000000
        print(f"\nRP2040 likely app start: 0x{b:08x} (offset 0x{off:x})")
    if st:
        bases = sorted({f.base for f in st if f.base is not None})
        pretty = ", ".join(f"0x{x:08x}" for x in bases)
        print(f"STM32 candidate app starts found: {pretty}")

    print(
        "\nNote: This report reduces guesswork from the reference snapshot, but SWD is the final authority."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
