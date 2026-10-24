#!/usr/bin/env python3
"""Verify the game dir against Steam's cached depot manifests (SHA-1 per file).

Usage: verify_steam.py <game_dir> <manifest> [<manifest> ...]

Prints MISMATCH / MISSING for shipped files and EXTRA for files Steam
did not ship. Exit code 1 if any shipped file is missing or differs.
"""

import hashlib
import io
import struct
import sys
import zipfile
from collections.abc import Iterator
from pathlib import Path

MAGIC_PAYLOAD = 0x71F617D0
MAGIC_METADATA = 0x1F4812BE
FLAG_DIRECTORY = 64

Field = int | bytes


def varint(buf: bytes, i: int) -> tuple[int, int]:
    n = shift = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        shift += 7
        if b < 0x80:
            return n, i


def fields(buf: bytes) -> Iterator[tuple[int, Field]]:
    """Yield (field number, value) of a protobuf message."""
    i = 0
    while i < len(buf):
        key, i = varint(buf, i)
        num, wire = key >> 3, key & 7
        val: Field
        if wire == 0:
            val, i = varint(buf, i)
        elif wire == 2:
            ln, i = varint(buf, i)
            val, i = buf[i : i + ln], i + ln
        elif wire == 1:
            val, i = buf[i : i + 8], i + 8
        elif wire == 5:
            val, i = buf[i : i + 4], i + 4
        else:
            raise ValueError(f"wire type {wire}")
        yield num, val


def as_bytes(v: Field | None) -> bytes:
    return v if isinstance(v, bytes) else b""


def as_int(v: Field | None) -> int:
    return v if isinstance(v, int) else 0


def sections(data: bytes) -> Iterator[tuple[int, bytes]]:
    if data[:2] == b"PK":  # depotcache files are sometimes zipped
        data = zipfile.ZipFile(io.BytesIO(data)).read("z")
    i = 0
    while i + 8 <= len(data):
        magic, ln = struct.unpack_from("<II", data, i)
        yield magic, data[i + 8 : i + 8 + ln]
        i += 8 + ln


def read_manifest(path: Path) -> dict[str, tuple[int, str]]:
    """{relative path: (size, sha1 hex)} for every file in the manifest."""
    files: dict[str, tuple[int, str]] = {}
    for magic, body in sections(path.read_bytes()):
        if magic == MAGIC_METADATA and as_int(dict(fields(body)).get(4)):
            raise SystemExit(f"{path}: filenames are encrypted")
        if magic != MAGIC_PAYLOAD:
            continue
        for num, mapping in fields(body):
            if num != 1:
                continue
            f = dict(fields(as_bytes(mapping)))
            if as_int(f.get(3)) & FLAG_DIRECTORY:
                continue
            name = as_bytes(f.get(1)).decode().rstrip("\0").replace("\\", "/")
            files[name] = (as_int(f.get(2)), as_bytes(f.get(5)).hex())
    return files


def sha1(path: Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as fh:
        while chunk := fh.read(1 << 22):
            h.update(chunk)
    return h.hexdigest()


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    game = Path(argv[0])
    shipped: dict[str, tuple[int, str]] = {}
    for m in argv[1:]:
        shipped.update(read_manifest(Path(m)))
    bad = 0
    for name, (size, digest) in sorted(shipped.items()):
        p = game / name
        if not p.is_file():
            print(f"MISSING  {name}")
            bad += 1
        elif p.stat().st_size != size or sha1(p) != digest:
            print(f"MISMATCH {name}")
            bad += 1
    local = {str(p.relative_to(game)) for p in game.rglob("*") if p.is_file()}
    extra = sorted(local - shipped.keys())
    for name in extra:
        print(f"EXTRA    {name}")
    print(f"{len(shipped)} shipped files checked, {bad} bad, {len(extra)} extra")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
