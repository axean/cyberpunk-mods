#!/usr/bin/env python3
"""Decode a Cyberpunk 2077 sav.dat: list nodes, dump one, read or diff facts.

    savdat.py nodes <sav.dat>                  node tree with offsets and sizes
    savdat.py dump <sav.dat> <node> [out]      write one node's bytes
    savdat.py facts <sav.dat> [name ...]       fact count, or values by name
    savdat.py factdiff <old> <new> [name ...]  facts that changed; names resolve hashes

Layout: "VASC" header, "FZLC" chunk table, LZ4 chunks ("4ZLX"), then a node
table found via the trailing <u32 offset>"ENOD". Facts are keyed by FNV-1a 32
of their name, in several FactsTable nodes under FactsDB.
"""

import struct
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

import lz4.block


@dataclass(frozen=True)
class Node:
    index: int
    name: str
    next: int
    child: int
    offset: int
    size: int


@dataclass(frozen=True)
class Save:
    data: bytes  # header followed by the decompressed chunks; node offsets index into this
    nodes: list[Node]

    def blob(self, node: Node) -> bytes:
        return self.data[node.offset : node.offset + node.size]


def varint(buf: bytes, i: int) -> tuple[int, int]:
    """CDPR packed int: bit 7 sign, bit 6 continue, 6 value bits; then 7 bits per byte."""
    b = buf[i]
    i += 1
    n = b & 0x3F
    shift = 6
    more = b & 0x40
    while more:
        c = buf[i]
        i += 1
        n |= (c & 0x7F) << shift
        shift += 7
        more = c & 0x80
    return (-n if b & 0x80 else n), i


def cstring(buf: bytes, i: int) -> tuple[str, int]:
    """CDPR string: varint length, negative means one byte per char, else UTF-16."""
    n, i = varint(buf, i)
    if n < 0:
        return buf[i : i - n].decode("latin-1"), i - n
    return buf[i : i + 2 * n].decode("utf-16-le"), i + 2 * n


def decompress(raw: bytes) -> bytes:
    if raw[:4] != b"VASC":
        raise ValueError("not a sav.dat")
    t = raw.index(b"FZLC")
    (count,) = struct.unpack_from("<I", raw, t + 4)
    chunks = [struct.unpack_from("<III", raw, t + 8 + 12 * k) for k in range(count)]
    out = bytearray(raw[: chunks[0][0]])
    for off, csize, dsize in chunks:
        magic, dsize2 = struct.unpack_from("<4sI", raw, off)
        if magic != b"4ZLX" or dsize2 != dsize:
            raise ValueError(f"bad chunk at {off:#x}")
        out += lz4.block.decompress(raw[off + 8 : off + csize], uncompressed_size=dsize)
    return bytes(out)


def read_nodes(raw: bytes) -> list[Node]:
    (table,) = struct.unpack_from("<I", raw, len(raw) - 8)
    if raw[-4:] != b"ENOD" or raw[table : table + 4] != b"EDON":
        raise ValueError("node table not found")
    count, i = varint(raw, table + 4)
    nodes: list[Node] = []
    for k in range(count):
        name, i = cstring(raw, i)
        nxt, child, off, size = struct.unpack_from("<iiII", raw, i)
        i += 16
        nodes.append(Node(k, name, nxt, child, off, size))
    return nodes


def load(path: str | Path) -> Save:
    raw = Path(path).read_bytes()
    return Save(decompress(raw), read_nodes(raw))


def fnv1a32(s: str) -> int:
    h = 0x811C9DC5
    for c in s.encode():
        h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF
    return h


def facts(save: Save) -> dict[tuple[int, int], int]:
    """{(table position, name hash): value}. Node indices shift between saves; positions don't."""
    out: dict[tuple[int, int], int] = {}
    tables = [n for n in save.nodes if n.name == "FactsTable"]
    for pos, node in enumerate(tables):
        buf = save.blob(node)
        n, i = varint(buf, 4)  # first 4 bytes: node index
        hashes = struct.unpack_from(f"<{n}I", buf, i)
        values = struct.unpack_from(f"<{n}i", buf, i + 4 * n)  # facts are signed
        out.update(((pos, h), v) for h, v in zip(hashes, values, strict=True))
    return out


def print_tree(nodes: list[Node]) -> None:
    by = {n.index: n for n in nodes}
    linked = {n.next for n in nodes} | {n.child for n in nodes}

    def walk(k: int, depth: int) -> None:
        while k != -1:
            n = by[k]
            print(f"{'  ' * depth}{n.name}  @{n.offset:#x} {n.size} B  [#{n.index}]")
            if n.child != -1:
                walk(n.child, depth + 1)
            k = n.next

    for n in nodes:
        if n.index not in linked:
            walk(n.index, 0)


def label(h: int, names: Iterable[str]) -> str:
    for name in names:
        if fnv1a32(name) == h:
            return name
    return f"{h:08x}"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[0], argv[1:]
    if cmd == "nodes":
        print_tree(load(args[0]).nodes)
    elif cmd == "dump":
        save = load(args[0])
        node = next((n for n in save.nodes if n.name == args[1]), None)
        if node is None:
            print(f"no node {args[1]!r}", file=sys.stderr)
            return 1
        out = Path(args[2] if len(args) > 2 else f"{args[1]}.bin")
        out.write_bytes(save.blob(node))
        print(f"{node.size} B -> {out}")
    elif cmd == "facts":
        table = facts(load(args[0]))
        if len(args) == 1:
            print(f"{len(table)} facts")
        for name in args[1:]:
            hits = [(pos, v) for (pos, h), v in table.items() if h == fnv1a32(name)]
            print(f"{name} = {', '.join(f'{v} (table {p})' for p, v in hits) or '<unset>'}")
    elif cmd == "factdiff":
        old, new = facts(load(args[0])), facts(load(args[1]))
        for key in sorted(old.keys() | new.keys()):
            if old.get(key) != new.get(key):
                pos, h = key
                print(f"table {pos}  {label(h, args[2:]):<32} {old.get(key)} -> {new.get(key)}")
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
