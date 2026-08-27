#!/usr/bin/env python3

"""Validate that the dynamic coordinate overlay has a renderable item surface."""

import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DISPLAY_IMAGE = ROOT / "images/ui/coordinate-background.png"


with (ROOT / "items/location_tracking.json").open(encoding="utf-8-sig") as source:
    items = json.load(source)


display = next(item for item in items if item["codes"] == "live_coordinates")
assert display["img"] == "images/ui/coordinate-background.png"
assert DISPLAY_IMAGE.is_file(), "coordinate display requires a background image"


with DISPLAY_IMAGE.open("rb") as source:
    signature = source.read(8)
    assert signature == b"\x89PNG\r\n\x1a\n", "coordinate background must be a PNG"
    chunk_length = struct.unpack(">I", source.read(4))[0]
    chunk_type = source.read(4)
    width, height = struct.unpack(">II", source.read(8))

assert chunk_length == 13 and chunk_type == b"IHDR"
assert (width, height) == (320, 32)


