#!/usr/bin/env python3
"""Bed-object detection hook used by PRINT_START when use_ai is enabled."""

from __future__ import annotations

import json
import sys
import time
import urllib.parse
import urllib.request
from typing import Optional, Tuple

try:
    import cv2  # type: ignore[import-not-found]
    import numpy as np  # type: ignore[import-not-found]
except Exception as exc:  # pragma: no cover - runtime dependency on printer OS
    print(f"[thinker-x400] cv.py skipped: missing cv2/numpy ({exc})", file=sys.stderr)
    raise SystemExit(0)


SNAPSHOT_URL = "http://127.0.0.1/webcam/?action=snapshot"
MOONRAKER_SCRIPT_URL = "http://127.0.0.1/printer/gcode/script?script="

WINDOW_WIDTH = 300
WINDOW_HEIGHT = 300
WINDOW_STEP = 20
START_X = 20
START_Y = 20
DEFAULT_OCCUPIED_THRESHOLD = 150


def _http_get(url: str, timeout: float = 2.0) -> bytes:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def _send_gcode(script: str) -> None:
    encoded = urllib.parse.quote(script, safe="")
    _http_get(f"{MOONRAKER_SCRIPT_URL}{encoded}", timeout=1.5)


def _load_snapshot() -> Optional["np.ndarray"]:
    try:
        image_bytes = _http_get(SNAPSHOT_URL, timeout=2.0)
    except Exception as exc:
        print(
            f"[thinker-x400] cv.py skipped: snapshot unavailable ({exc})",
            file=sys.stderr,
        )
        return None

    image_array = np.asarray(bytearray(image_bytes), dtype="uint8")
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        print(
            "[thinker-x400] cv.py skipped: failed to decode webcam snapshot",
            file=sys.stderr,
        )
        return None
    return image


def _compute_binary_mask(image: "np.ndarray") -> "np.ndarray":
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    invert = cv2.bitwise_not(gray)
    blur = cv2.GaussianBlur(invert, (21, 21), 0)
    inverted_blur = cv2.bitwise_not(blur)
    sketch = cv2.divide(gray, inverted_blur, scale=256.0)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (8, 8))
    bg = cv2.morphologyEx(sketch, cv2.MORPH_DILATE, kernel)
    normalized = cv2.divide(sketch, bg, scale=255)
    _, binary_mask = cv2.threshold(normalized, 0, 1, cv2.THRESH_OTSU)
    return binary_mask


def _scan_min_occupied_area(binary_mask: "np.ndarray") -> Tuple[int, int, int]:
    height, width = binary_mask.shape[:2]
    total = WINDOW_WIDTH * WINDOW_HEIGHT
    best = total
    best_x = 0
    best_y = 0

    if height < WINDOW_HEIGHT or width < WINDOW_WIDTH:
        occupied = total - int(np.sum(binary_mask))
        return occupied, best_x, best_y

    for y in range(START_Y, height, WINDOW_STEP):
        if y > height - WINDOW_HEIGHT:
            continue
        for x in range(START_X, width, WINDOW_STEP):
            if x > width - WINDOW_WIDTH:
                continue
            window_sum = int(
                np.sum(binary_mask[y : y + WINDOW_HEIGHT, x : x + WINDOW_WIDTH])
            )
            occupied = total - window_sum
            if occupied < best:
                best = occupied
                best_x = x
                best_y = y
    return best, best_x, best_y


def main() -> int:
    # Keep legacy call compatibility: first arg is accepted but intentionally ignored.
    _ = sys.argv[1:] if len(sys.argv) > 1 else []

    start = time.time()
    image = _load_snapshot()
    if image is None:
        return 0
    loaded = time.time()

    binary_mask = _compute_binary_mask(image)
    masked = time.time()

    occupied, pos_x, pos_y = _scan_min_occupied_area(binary_mask)
    scanned = time.time()

    print(f"max pos===x:{pos_x} y:{pos_y} sum:{occupied}")
    print(
        json.dumps(
            {
                "fetch_s": round(loaded - start, 3),
                "preprocess_s": round(masked - loaded, 3),
                "scan_s": round(scanned - masked, 3),
            }
        )
    )

    if occupied > DEFAULT_OCCUPIED_THRESHOLD:
        try:
            _send_gcode(f"M117 =bed_obj{occupied}")
            _send_gcode("PAUSE")
        except Exception as exc:
            print(
                f"[thinker-x400] cv.py warning: failed to send PAUSE ({exc})",
                file=sys.stderr,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
