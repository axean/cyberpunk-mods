#!/usr/bin/env python3
"""Capture Faith's movement from a running Mirror's Edge (2008, Steam) as JSONL, for reference.

    me_capture.py [--hz 60] [--out captures/mirrors-edge]

Reads the game's memory from outside (/proc/<pid>/mem); nothing is injected or changed. Writes
one JSON object per line to <out>/<start time>.jsonl until the game exits or Ctrl+C.

Memory layout from megem (github.com/totenhack/megem, Apache-2.0, DLL/player.h) and the
LiveSplit autosplitter (github.com/Degaussed/Livesplit-ASL-scripts). Positions and velocities
are in Unreal units; rotations are converted from 65536 = 360 degrees.
"""

import argparse
import json
import re
import struct
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, BinaryIO

IMAGE = 0x400000
# mov [static], ecx; mov ecx, imm32; ... : the 4 bytes after 89 0D are the static base pointer
STATIC_PATTERN = re.compile(rb"\x89\x0D(....)\xB9....\xFF", re.S)
PLAYER_CHAIN = (0xCC, 0x4A4, 0x214)
LEVEL_BASE, LEVEL_CHAIN = 0x01BF8B20, (0x3CC,)

FLOATS = {"pos": (0xE8, 0xEC, 0xF0), "vel": (0x100, 0x104, 0x108)}
ROTATION = (0xF4, 0xF8, 0xFC)  # pitch, yaw, roll
BYTES = {"move": 0x4FE, "walk": 0x503, "action": 0x505, "wallrun": 0x2A0, "wall": 0x2A8}
HEALTH = 0x2B8


def find_pid() -> int:
    out = subprocess.run(["pgrep", "-x", "MirrorsEdge.exe"], capture_output=True, text=True)
    pids = out.stdout.split()
    if not pids:
        sys.exit("Mirror's Edge is not running")
    return int(pids[0])


def degrees(unreal: int) -> float:
    """Unreal rotation units (65536 per turn) to degrees in [0, 360)."""
    return (unreal % 0x10000) * 360 / 0x10000


def find_static(image: bytes) -> int:
    match = STATIC_PATTERN.search(image)
    if not match:
        raise LookupError("static base pattern not found (unsupported game version?)")
    return struct.unpack("<I", match.group(1))[0]


class Game:
    def __init__(self, pid: int) -> None:
        self.mem: BinaryIO = open(f"/proc/{pid}/mem", "rb")  # noqa: SIM115
        self.static = find_static(self.read(IMAGE, 0x1B53000))

    def read(self, address: int, size: int) -> bytes:
        self.mem.seek(address)
        return self.mem.read(size)

    def u32(self, address: int) -> int:
        return struct.unpack("<I", self.read(address, 4))[0]

    def f32(self, address: int) -> float:
        return struct.unpack("<f", self.read(address, 4))[0]

    def follow(self, base: int, chain: tuple[int, ...]) -> int:
        p = self.u32(base)
        for offset in chain:
            p = self.u32(p + offset)
        return p

    def level(self) -> str:
        p = self.follow(IMAGE + LEVEL_BASE, LEVEL_CHAIN)
        return self.read(p, 64).decode("utf-16-le", "ignore").split("\x00")[0]

    def sample(self) -> dict[str, Any]:
        p = self.follow(self.static, PLAYER_CHAIN)
        row: dict[str, Any] = {"level": self.level()}
        for name, offsets in FLOATS.items():
            row[name] = [round(self.f32(p + o), 2) for o in offsets]
        vx, vy, vz = row["vel"]
        row["speed_h"] = round((vx * vx + vy * vy) ** 0.5, 1)
        row["speed"] = round((vx * vx + vy * vy + vz * vz) ** 0.5, 1)
        pitch, yaw, roll = (degrees(self.u32(p + o)) for o in ROTATION)
        row["rot"] = [round(pitch, 1), round(yaw, 1), round(roll, 1)]
        for name, offset in BYTES.items():
            row[name] = self.read(p + offset, 1)[0]
        row["health"] = round(self.f32(p + HEALTH), 1)
        return row


def main() -> None:
    parser = argparse.ArgumentParser(description="Capture Faith's movement from Mirror's Edge.")
    parser.add_argument("--hz", type=float, default=60)
    parser.add_argument("--out", type=Path, default=Path("captures/mirrors-edge"))
    args = parser.parse_args()
    pid = find_pid()
    game = Game(pid)
    args.out.mkdir(parents=True, exist_ok=True)
    path = args.out / f"{datetime.now():%Y%m%d-%H%M%S}.jsonl"
    print(f"capturing pid {pid} at {args.hz:g} Hz to {path}", flush=True)
    start = time.monotonic()
    period = 1 / args.hz
    with path.open("w") as out:
        try:
            while Path(f"/proc/{pid}").exists():
                t = time.monotonic() - start
                try:
                    row = {"t": round(t, 3), **game.sample()}
                except (OSError, struct.error):
                    row = {"t": round(t, 3), "error": "unreadable (loading?)"}
                out.write(json.dumps(row, separators=(",", ":")) + "\n")
                out.flush()
                time.sleep(max(0.0, start + t + period - time.monotonic()))
        except KeyboardInterrupt:
            pass
    print(f"stopped; {path}")


if __name__ == "__main__":
    main()
