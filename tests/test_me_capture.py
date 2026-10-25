import json
import struct

import me_capture


def test_degrees_wraps_unreal_rotation() -> None:
    assert me_capture.degrees(0x4000) == 90
    assert me_capture.degrees(0x10000 + 0x8000) == 180
    assert me_capture.degrees(-0x4000) == 270


def test_find_static_reads_pointer_after_pattern() -> None:
    image = (
        b"\x00" * 7 + b"\x89\x0d" + struct.pack("<I", 0x1F73F1C) + b"\xb9" + b"\x01" * 4 + b"\xff"
    )
    assert me_capture.find_static(image) == 0x1F73F1C


def test_crop_drops_menu_errors_and_standstill() -> None:
    def row(pos: list[float], level: str = "tutorial_p") -> str:
        return json.dumps({"level": level, "pos": pos, "rot": [0, 0, 0], "move": 1}) + "\n"

    lines = [
        row([0, 0, 0], "TdMainMenu"),
        json.dumps({"t": 1, "error": "unreadable (loading?)"}) + "\n",
        row([1, 0, 0]),
        row([1, 0, 0]),
        row([2, 0, 0]),
    ]
    assert me_capture.crop(lines) == [lines[2], lines[4]]
