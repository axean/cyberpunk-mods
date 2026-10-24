import json
from pathlib import Path
from typing import Any

import questgraph


def cname(s: str) -> dict[str, str]:
    return {"$type": "CName", "$storage": "string", "$value": s}


def socket(hid: str, name: str, kind: str, conns: list[Any]) -> dict[str, Any]:
    return {
        "HandleId": hid,
        "Data": {
            "$type": "questSocketDefinition",
            "name": cname(name),
            "type": kind,
            "connections": conns,
        },
    }


def conn(hid: str, src: str, dst: str) -> dict[str, Any]:
    data = {"source": {"HandleRefId": src}, "destination": {"HandleRefId": dst}}
    return {"HandleId": hid, "Data": {"$type": "graphGraphConnectionDefinition", **data}}


def handles(items: list[dict[str, Any]], first: int) -> list[dict[str, Any]]:
    return [{"HandleId": str(first + i), "Data": x} for i, x in enumerate(items)]


def questphase() -> dict[str, Any]:
    """in -> (my_fact == 0 ?) -True-> set my_fact = 1 -> out; -False-> out."""
    comparison = {
        "$type": "questVarComparison_ConditionType",
        "factName": "my_fact",
        "comparisonType": "Equal",
        "value": 0,
    }
    cond = {"$type": "questFactsDBCondition", "type": {"HandleId": "90", "Data": comparison}}
    setvar = {
        "$type": "questSetVar_NodeType",
        "factName": "my_fact",
        "value": 1,
        "setExactValue": 1,
    }
    nodes = [
        {"$type": "questInputNodeDefinition", "id": 0, "socketName": cname("In1"),
         "sockets": [socket("10", "Out", "Output", [conn("50", "10", "20")])]},
        {"$type": "questConditionNodeDefinition", "id": 1,
         "condition": {"HandleId": "91", "Data": cond},
         "sockets": [socket("20", "In", "Input", []),
                     socket("21", "True", "Output", [conn("51", "21", "30")]),
                     socket("22", "False", "Output", [conn("52", "22", "40")])]},
        {"$type": "questFactsDBManagerNodeDefinition", "id": 2,
         "type": {"HandleId": "92", "Data": setvar},
         "sockets": [socket("30", "In", "Input", []),
                     socket("31", "Out", "Output", [conn("53", "31", "40")])]},
        {"$type": "questOutputNodeDefinition", "id": 3, "socketName": cname("Out1"),
         "sockets": [socket("40", "In", "Input", [])]},
    ]  # fmt: skip
    graph = {
        "$type": "questGraphDefinition",
        "nodes": [{"HandleId": str(100 + i), "Data": n} for i, n in enumerate(nodes)],
    }
    root = {"$type": "questQuestPhaseResource", "graph": {"HandleId": "1", "Data": graph}}
    return {"Data": {"RootChunk": root}}


def scene() -> dict[str, Any]:
    """start -> choice -[Smoke]-> section (anim) -> end."""

    def out(*dst: int, name: int = 0, ordinal: int = 0) -> dict[str, Any]:
        return {
            "stamp": {"name": name, "ordinal": ordinal},
            "destinations": [{"nodeId": {"id": d}} for d in dst],
        }

    anim = {"$type": "scnAnimName", "unk1": [cname("stand__smoke__01")]}
    event = {"$type": "scnPlaySkAnimEvent", "animName": {"HandleId": "61", "Data": anim}}
    nodes: list[dict[str, Any]] = [
        {"$type": "scnStartNode", "nodeId": {"id": 1}, "outputSockets": [out(5)]},
        {"$type": "scnChoiceNode", "nodeId": {"id": 5}, "outputSockets": [out(7)],
         "options": [{"screenplayOptionId": {"id": 2}}]},
        {"$type": "scnSectionNode", "nodeId": {"id": 7}, "outputSockets": [out(2)],
         "sectionDuration": {"stu": 4000},
         "events": [{"HandleId": "60", "Data": event}]},
        {"$type": "scnEndNode", "nodeId": {"id": 2}, "outputSockets": []},
    ]  # fmt: skip
    store = {"options": [{"itemId": {"id": 2}, "locstringId": {"ruid": "123"}}]}
    root: dict[str, Any] = {
        "$type": "scnSceneResource",
        "props": [],
        "screenplayStore": store,
        "sceneGraph": {"HandleId": "1", "Data": {"graph": handles(nodes, 10)}},
    }  # fmt: skip
    return {"Data": {"RootChunk": root}}


def test_questphase_nodes_and_branch_labels() -> None:
    g = questgraph.build(questphase(), {})
    assert g.nodes["1"].kind == "decision"
    assert g.nodes["1"].label.startswith("my_fact == 0 ?")
    assert g.nodes["2"].label.startswith("set my_fact = 1")
    assert questgraph.Edge("1", "2", "True") in g.edges
    assert questgraph.Edge("1", "3", "False") in g.edges
    assert questgraph.Edge("0", "1", "") in g.edges


def test_scene_choice_caption_from_loc(tmp_path: Path) -> None:
    loc = tmp_path / "subs.json"
    loc.write_text(json.dumps({"entries": [{"stringId": "123", "femaleVariant": "[Smoke]"}]}))
    g = questgraph.build(scene(), questgraph.load_loc([loc]))
    assert questgraph.Edge("5", "7", "[Smoke]") in g.edges
    assert "anim stand__smoke__01" in g.nodes["7"].label
    assert g.nodes["7"].label.startswith("section 4.0 s")


def test_reachable_stops_and_dot_marks_loops() -> None:
    g = questgraph.build(questphase(), {})
    g.link("3", "1")  # add a loop
    sub = questgraph.reachable(g, ["1"], stop={"2"})
    assert set(sub.nodes) == {"1", "2", "3"}
    dot = questgraph.to_dot(sub, "t", ["1"])
    assert '"3" -> "1" [style=dashed constraint=false];' in dot


def test_fold_merges_twins() -> None:
    g = questgraph.Graph()
    for key, item in [("10", "Items.Beer"), ("11", "Items.Wine")]:
        g.add(questgraph.Node(key, "action", f"remove {item} x1\n[{key}]"))
        g.link("s", key)
        g.link(key, "e")
    g.add(questgraph.Node("s", "start", "s"))
    g.add(questgraph.Node("e", "end", "e"))
    folded = questgraph.fold(g)
    assert len(folded.nodes) == 3
    assert "(+1 similar)" in folded.nodes["10"].label
