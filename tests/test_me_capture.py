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
