import json

import devlog


def test_crop_keeps_marks_and_changes_only() -> None:
    def row(x: float, loc: str = "Default") -> str:
        return (
            json.dumps({"t": x, "pos": [x, 0, 0], "cam_rot": [0, 0, 0], "locomotion": loc}) + "\n"
        )

    still = json.dumps({"t": 2, "pos": [1, 0, 0], "cam_rot": [0, 0, 0], "locomotion": "Default"})
    lines = [row(1), still + "\n", json.dumps({"t": 2.5, "mark": 1}) + "\n", row(3, "Jump")]
    assert devlog.crop(lines) == [lines[0], lines[2], lines[3]]
