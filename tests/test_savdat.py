import struct
from pathlib import Path

import lz4.block
import pytest

import savdat


def test_fnv1a32_reference_vectors() -> None:
    assert savdat.fnv1a32("") == 0x811C9DC5
    assert savdat.fnv1a32("a") == 0xE40C292C
    assert savdat.fnv1a32("foobar") == 0xBF9CF968


@pytest.mark.parametrize("value", [0, 5, 63, 64, 286, 100_000, -1, -13, -300])
def test_varint_roundtrip(value: int) -> None:
    assert savdat.varint(pack_varint(value), 0) == (value, len(pack_varint(value)))


def test_cstring_ascii_and_utf16() -> None:
    assert savdat.cstring(pack_varint(-4) + b"Core", 0) == ("Core", 5)
    assert savdat.cstring(pack_varint(2) + "hé".encode("utf-16-le"), 0) == ("hé", 5)


def test_load_synthetic_save(tmp_path: Path) -> None:
    path = tmp_path / "sav.dat"
    path.write_bytes(synthetic_save({"q101_done": 1, "my_mod_slot": 22}))
    save = savdat.load(path)
    assert [n.name for n in save.nodes] == ["FactsDB", "FactsTable"]
    hashed = {h: v for (_, h), v in savdat.facts(save).items()}
    assert hashed == {savdat.fnv1a32("q101_done"): 1, savdat.fnv1a32("my_mod_slot"): 22}


def pack_varint(value: int) -> bytes:
    n = abs(value)
    first = (0x80 if value < 0 else 0) | (n & 0x3F)
    n >>= 6
    out = bytearray()
    if n:
        first |= 0x40
    out.append(first)
    while n:
        b = n & 0x7F
        n >>= 7
        out.append(b | (0x80 if n else 0))
    return bytes(out)


def synthetic_save(fact_values: dict[str, int]) -> bytes:
    """Header, one LZ4 chunk with a FactsDB > FactsTable pair, node table."""
    hashes = [savdat.fnv1a32(k) for k in fact_values]
    table = struct.pack("<i", 1) + pack_varint(len(hashes))
    table += struct.pack(f"<{len(hashes)}I", *hashes)
    table += struct.pack(f"<{len(hashes)}I", *fact_values.values())
    db = struct.pack("<i", 0)
    payload = db + table

    header_size = 4 + 4 + 4 + 12  # VASC, FZLC, count, one chunk entry
    compressed = lz4.block.compress(payload, store_size=False)
    chunk = b"4ZLX" + struct.pack("<I", len(payload)) + compressed
    chunk_at = header_size
    header = b"VASC" + b"FZLC" + struct.pack("<I", 1)
    header += struct.pack("<III", chunk_at, len(chunk), len(payload))

    nodes = [
        ("FactsDB", -1, 1, header_size, len(payload)),
        ("FactsTable", -1, -1, header_size + len(db), len(table)),
    ]
    node_table = b"EDON" + pack_varint(len(nodes))
    for name, nxt, child, off, size in nodes:
        node_table += (
            pack_varint(-len(name)) + name.encode() + struct.pack("<iiII", nxt, child, off, size)
        )
    body = header + chunk
    return body + node_table + struct.pack("<I", len(body)) + b"ENOD"
