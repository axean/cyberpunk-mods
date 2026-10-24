#!/usr/bin/env python3
"""Verify the game dir against Steam's cached depot manifests (SHA-1 per file).

Usage: verify_steam.py <game_dir> <manifest> [<manifest> ...]

Prints MISMATCH / MISSING for shipped files and EXTRA for files Steam
did not ship. Exit code 1 if any shipped file is missing or differs.
"""
import hashlib
import struct
import sys
from pathlib import Path

MAGIC_PAYLOAD = 0x71F617D0
MAGIC_METADATA = 0x1F4812BE
FLAG_DIRECTORY = 64


def varint(buf, i):
    n = shift = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        shift += 7
        if b < 0x80:
            return n, i


def fields(buf):
    """Yield (field_number, value) for a protobuf message; values are int or bytes."""
    i = 0
    while i < len(buf):
        key, i = varint(buf, i)
        num, wire = key >> 3, key & 7
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


def sections(data):
    if data[:2] == b"PK":  # depotcache files are sometimes zipped
        import io
        import zipfile

        data = zipfile.ZipFile(io.BytesIO(data)).read("z")
    i = 0
    while i + 8 <= len(data):
        magic, ln = struct.unpack_from("<II", data, i)
        yield magic, data[i + 8 : i + 8 + ln]
        i += 8 + ln


def read_manifest(path):
    files, meta = {}, {}
    for magic, body in sections(Path(path).read_bytes()):
        if magic == MAGIC_METADATA:
            meta = dict(fields(body))
        elif magic == MAGIC_PAYLOAD:
            for num, m in fields(body):
                if num != 1:
                    continue
                f = dict(fields(m))
                if f.get(3, 0) & FLAG_DIRECTORY:
                    continue
                name = f[1].decode().rstrip("\0").replace("\\", "/")
                files[name] = (f.get(2, 0), f.get(5, b"").hex())
    if meta.get(4):
        sys.exit(f"{path}: filenames are encrypted")
    return files


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as fh:
        while chunk := fh.read(1 << 22):
            h.update(chunk)
    return h.hexdigest()


def main():
    game = Path(sys.argv[1])
    shipped = {}
    for m in sys.argv[2:]:
        shipped.update(read_manifest(m))
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
    for name in sorted(local - shipped.keys()):
        print(f"EXTRA    {name}")
    print(f"{len(shipped)} shipped files checked, {bad} bad, {len(local - shipped.keys())} extra")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
