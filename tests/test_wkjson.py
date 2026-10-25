import base64
import struct
from typing import Any

import wkjson as wk


def test_shared_handle_written_once_then_referenced() -> None:
    shared = wk.Handle({"$type": "x"})
    out: Any = wk.encode({"a": shared, "b": [shared]}, {})
    assert out == {"a": {"HandleId": "0", "Data": {"$type": "x"}}, "b": [{"HandleRefId": "0"}]}


def test_connect_wires_both_sockets() -> None:
    g = wk.Graph()
    a = g.add(wk.input_node(0))
    b = g.add(wk.output_node(1))
    g.connect(a, b)
    (c,) = a.sockets["Out"].data["connections"]
    assert b.sockets["In"].data["connections"] == [c]
    assert c.data["source"] is a.sockets["Out"]
    assert c.data["destination"] is b.sockets["In"]


def test_phase_encodes_cycles_as_refs() -> None:
    g = wk.Graph()
    g.connect(g.add(wk.input_node(0)), g.add(wk.set_fact_node(1, "f", 1)))
    doc: Any = wk.document(g.phase())
    nodes = doc["Data"]["RootChunk"]["graph"]["Data"]["nodes"]
    assert [n["Data"]["id"] for n in nodes] == [0, 1]
    # the set-fact node's In socket was first written inside the input node's connection
    assert "HandleRefId" in nodes[1]["Data"]["sockets"][1]


def test_loc_string_matches_onscreen_key() -> None:
    entry: Any = wk.onscreens({"k": "Hello"})["root"].data["entries"][0]
    assert wk.loc_string("k")["value"] == f"LocKey#{entry['primaryKey']}"
    assert int(entry["primaryKey"]) < 2**63


def test_outline_buffer_holds_points_and_height() -> None:
    sector: Any = wk.trigger_sector("$/#t", 1, (10, 10, 10), "t")
    outline = sector["nodes"][0].data["outline"].data
    raw = base64.b64decode(outline["buffer"])
    assert struct.unpack_from("<I", raw) == (4,)
    assert struct.unpack_from("<4f", raw, 4) == (-1, -1, 0, 1)
    assert struct.unpack_from("<f", raw, 4 + 16 * 4) == (outline["height"],)
