#!/usr/bin/env python3
"""Render a quest graph (.quest, .questphase or .scene, as WolvenKit JSON) as a flowchart.

    questgraph.py <file.json> [-o out.svg|.png|.pdf|.dot] [--from ID ...] [--stop ID ...]
                  [--loc strings.json ...] [--fold]

Input is the output of `tools/wk convert serialize`. Without -o, prints Graphviz DOT.
--from keeps only nodes reachable from the given node ids; --stop shows those nodes but
does not follow them (e.g. a loop back to a choice). Node ids are shown in each box.
--loc resolves choice captions from subtitle/onscreen JSON files. --fold merges sibling
nodes that differ only in names or numbers (e.g. one inventory check per item).

Loops are drawn as dashed edges. Shapes: rounded = start/end, diamond = decision,
hexagon = wait until, box = action, double box = phase or scene call,
parallelogram = player choice, note = scene section.
"""

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, TypeGuard

J = Any  # a parsed WolvenKit JSON value


def is_dict(o: J) -> TypeGuard[dict[str, J]]:
    return isinstance(o, dict)


def is_list(o: J) -> TypeGuard[list[J]]:
    return isinstance(o, list)


def obj(o: J) -> dict[str, J]:
    return o if is_dict(o) else {}


JOURNAL_STATES = ("Active", "Inactive", "Succeeded", "Failed")

OPS = {
    "Equal": "==",
    "NotEqual": "!=",
    "Greater": ">",
    "GreaterOrEqual": ">=",
    "Less": "<",
    "LessOrEqual": "<=",
}

STYLE = {
    "start": 'shape=box style="rounded,filled" fillcolor="#d5e8d4" color="#82b366"',
    "end": 'shape=box style="rounded,filled" fillcolor="#f8cecc" color="#b85450"',
    "decision": 'shape=diamond style=filled fillcolor="#fff2cc" color="#d6b656"',
    "wait": 'shape=hexagon style=filled fillcolor="#fff2cc" color="#d6b656"',
    "action": 'shape=box style=filled fillcolor="#dae8fc" color="#6c8ebf"',
    "call": 'shape=box style=filled fillcolor="#e1d5e7" color="#9673a6" peripheries=2',
    "choice": 'shape=parallelogram style=filled fillcolor="#ffe6cc" color="#d79b00"',
    "section": 'shape=note style=filled fillcolor="#f5f5f5" color="#666666"',
    "hub": 'shape=circle style=filled fillcolor="#666666" color="#666666" fontcolor="#ffffff"',
    "note": 'shape=box style="dashed" color="#999999" fontcolor="#999999"',
}


@dataclass
class Node:
    key: str
    kind: str
    label: str
    cluster: str = ""


@dataclass
class Edge:
    src: str
    dst: str
    label: str = ""


@dataclass
class Graph:
    nodes: dict[str, Node] = field(default_factory=dict[str, Node])
    edges: list[Edge] = field(default_factory=list[Edge])
    clusters: dict[str, tuple[str, str]] = field(default_factory=dict[str, tuple[str, str]])

    def add(self, node: Node) -> None:
        self.nodes[node.key] = node

    def link(self, src: str, dst: str, label: str = "") -> None:
        edge = Edge(src, dst, label)
        if edge not in self.edges:
            self.edges.append(edge)


class Handles:
    """WolvenKit stores shared objects once ({"HandleId", "Data"}) and refers to them later."""

    def __init__(self, root: J) -> None:
        self.table: dict[str, J] = {}
        self._index(root)

    def _index(self, o: J) -> None:
        if is_dict(o):
            if "HandleId" in o and "Data" in o:
                self.table[o["HandleId"]] = o["Data"]
            for v in o.values():
                self._index(v)
        elif is_list(o):
            for v in o:
                self._index(v)

    def get(self, h: J) -> J:
        if is_dict(h) and "HandleRefId" in h:
            return self.table.get(h["HandleRefId"])
        if is_dict(h) and "HandleId" in h:
            return h.get("Data")
        return h

    @staticmethod
    def id_of(h: J) -> str:
        return h.get("HandleRefId") or h.get("HandleId") or ""


def value(x: J) -> J:
    """Unwrap CName / ResourcePath / TweakDBID wrappers."""
    while is_dict(x) and ("$value" in x or "DepotPath" in x):
        x = x.get("$value", x.get("DepotPath"))
    return x


def basename(path: J) -> str:
    return str(value(path)).replace("\\", "/").rsplit("/", 1)[-1]


def short_type(t: str) -> str:
    t = re.sub(r"^(quest|scnevents|scn|game)", "", t)
    return re.sub(r"(_ConditionType|_NodeType|NodeTypeParams|NodeDefinition|Condition)$", "", t)


def summary(o: J, h: Handles) -> str:
    """Type name plus a few non-default scalar fields."""
    o = h.get(o)
    if not is_dict(o):
        return str(o)
    fields: list[str] = []
    for k, v in o.items():
        v = value(v)
        if k.startswith("$") or is_dict(v) or is_list(v) or v in (None, "", 0, "0", "None"):
            continue
        fields.append(f"{k}={v}")
    return " ".join([short_type(str(o.get("$type", "?")))] + fields[:3])


def walk(o: J, t: str) -> list[J]:
    """All dicts of $type t below o."""
    out: list[J] = []
    if is_dict(o):
        if o.get("$type") == t:
            out.append(o)
        for v in o.values():
            out += walk(v, t)
    elif is_list(o):
        for v in o:
            out += walk(v, t)
    return out


def cond_text(c: J, h: Handles, nested: bool = False) -> str:
    c = h.get(c)
    if not is_dict(c):
        return "?"
    t = str(c.get("$type", ""))
    if t == "questVarComparison_ConditionType":
        op = OPS.get(c.get("comparisonType", ""), c.get("comparisonType"))
        return f"{value(c.get('factName'))} {op} {c.get('value')}"
    if t == "questLogicalCondition":
        op = str(c.get("operation", "AND"))
        parts = [cond_text(x, h, nested=True) for x in c.get("conditions", [])]
        if op == "NOT":
            return f"NOT ({' AND '.join(parts)})"
        if len(parts) == 1:
            return parts[0]
        if nested:
            return "(" + f" {op} ".join(parts) + ")"
        return f"\n{op} ".join(parts)
    if t == "questTriggerCondition":
        where = "inside" if c.get("type") == "IsInside" else "outside"
        return f"player {where} {value(c.get('triggerAreaRef'))}"
    if t == "questInputAction_ConditionType":
        action = value(c.get("inputAction"))
        if c.get("axisAction"):
            return f"input {action} in ({c.get('valueMoreThan'):.1f}, {c.get('valueLessThan'):.1f})"
        return f"input {action} pressed"
    if t == "questRealtimeDelay_ConditionType":
        return f"{c.get('seconds', 0)} s passed"
    if t == "questInventory_ConditionType":
        op = OPS.get(c.get("comparisonType", ""), c.get("comparisonType"))
        return f"has {value(c.get('itemID'))} {op} {c.get('quantity', 1)}"
    if t == "questJournalEntryState_ConditionType":
        paths = [p.get("realPath") for p in walk(c, "gameJournalPath")]
        return f"journal {paths[0] if paths else '?'} is {c.get('state')}"
    if "type" in c and is_dict(c["type"]):  # wrapper conditions
        return cond_text(c["type"], h, nested)
    return summary(c, h)


def quest_node(q: J, h: Handles) -> tuple[str, str]:
    """(kind, label) for a quest node definition."""
    t = str(q.get("$type", ""))
    inner = h.get(q.get("type")) if is_dict(q.get("type")) else None
    if t == "questFactsDBManagerNodeDefinition" and is_dict(inner):
        op = "=" if inner.get("setExactValue") else "+="
        return "action", f"set {value(inner.get('factName'))} {op} {inner.get('value')}"
    if t == "questPauseConditionNodeDefinition":
        return "wait", "wait until\n" + cond_text(q.get("condition"), h)
    if t == "questConditionNodeDefinition":
        return "decision", cond_text(q.get("condition"), h) + " ?"
    if t == "questSceneNodeDefinition":
        return "call", "scene\n" + basename(q.get("sceneFile"))
    if t == "questPhaseNodeDefinition":
        return "call", "phase\n" + basename(q.get("phaseResource"))
    if t == "questStartNodeDefinition":
        return "start", "start"
    if t == "questEndNodeDefinition":
        return "end", "end"
    if t == "questInputNodeDefinition":
        return "start", f"in: {value(q.get('socketName'))}"
    if t == "questOutputNodeDefinition":
        return "end", f"out: {value(q.get('socketName'))}"
    if t == "questDeletionMarkerNodeDefinition":
        return "note", "marker"  # editor leftover; flow can still pass through it
    if t in ("questLogicalHubNodeDefinition", "questHubNodeDefinition"):
        return "hub", ""
    if t.startswith("questLogical"):
        return "hub", short_type(t).replace("Logical", "")
    if t == "questItemManagerNodeDefinition":
        params = walk(q, "questAddRemoveItem_NodeTypeParams")
        lines = [
            f"{'add' if p.get('nodeType') == 'AddItem' else 'remove'} "
            f"{value(p.get('itemID'))} x{p.get('quantity', 1)}"
            for p in params
        ]
        return "action", "\n".join(lines) or "items"
    if t == "questJournalNodeDefinition":
        paths = [p.get("realPath") for p in walk(q, "gameJournalPath")]
        return "action", f"journal: {summary(inner, h)}" + (f"\n{paths[0]}" if paths else "")
    if t == "questUseWorkspotNodeDefinition":
        entries = walk(q, "workWorkEntryId")
        return "action", f"V uses workspot entry {entries[0].get('id') if entries else '?'}"
    label = short_type(t) + (f"\n{summary(inner, h)}" if inner is not None else "")
    return "action", label


def wrap(name: str, width: int = 44) -> str:
    """Break long animation names at '__' so boxes stay narrow."""
    lines: list[str] = []
    line = ""
    for part in name.split("__"):
        piece = part if not line else "__" + part
        if line and len(line) + len(piece) > width:
            lines.append(line)
            piece = part
            line = ""
        line += piece
    return "\n  ".join(lines + [line])


def section(n: J, scene: J, h: Handles) -> str:
    props = {p["propId"]["id"]: value(p.get("propName")) for p in scene.get("props", [])}
    stu = obj(n.get("sectionDuration")).get("stu", 0)
    lines = [f"section {stu / 1000:.1f} s"]
    others: dict[str, int] = defaultdict(int)
    for e in (h.get(x) for x in n.get("events", [])):
        t = str(e.get("$type", ""))
        if t == "scnPlaySkAnimEvent":
            names = obj(h.get(e.get("animName"))).get("unk1") or ["?"]
            lines.append("anim " + wrap(str(value(names[0]))))
        elif t == "scneventsAttachPropToPerformer":
            lines.append(f"prop {props.get(e['propId']['id'], '?')} -> {value(e.get('slot'))}")
        elif t == "scneventsEquipItemToPerformer":
            lines.append(f"equip {value(e.get('itemId'))}")
        else:
            others[short_type(t)] += 1
    lines += [f"{k} x{v}" for k, v in sorted(others.items())]
    return "\n".join(lines)


def questphase_graph(g: Graph, graph_def: J, h: Handles, prefix: str, cluster: str) -> None:
    nodes = [h.get(n) for n in graph_def.get("nodes", [])]
    owner: dict[str, tuple[str, str]] = {}
    inner_io: dict[str, dict[str, str]] = {}  # inline phase key -> socket name -> inner node
    for n in nodes:
        key = f"{prefix}{n['id']}"
        for s in n.get("sockets", []):
            owner[Handles.id_of(s)] = (key, str(value(h.get(s).get("name"))))
        sub = h.get(n.get("phaseGraph")) if n.get("phaseGraph") else None
        if sub and sub.get("nodes"):
            resource = str(value(n.get("phaseResource")))
            title = basename(resource) if resource not in ("", "0", "None") else ""
            g.clusters[key] = (f"phase {n['id']} {title}".strip(), cluster)
            questphase_graph(g, sub, h, f"{key}/", key)
            inner_io[key] = {
                str(value(h.get(x).get("socketName"))): f"{key}/{h.get(x)['id']}"
                for x in sub["nodes"]
                if h.get(x).get("$type")
                in ("questInputNodeDefinition", "questOutputNodeDefinition")
            }
            continue
        kind, label = quest_node(n, h)
        g.add(Node(key, kind, f"{label}\n[{n['id']}]" if label else str(n["id"]), cluster))
    for n in nodes:
        for s in n.get("sockets", []):
            sd = h.get(s)
            if sd.get("type") != "Output":
                continue
            for c in sd.get("connections", []):
                cd = h.get(c)
                src = owner.get(Handles.id_of(cd["source"]))
                dst = owner.get(Handles.id_of(cd["destination"]))
                if not src or not dst:
                    continue
                skey, sname = src
                dkey, dname = dst
                skey = inner_io.get(skey, {}).get(sname, skey)
                dkey = inner_io.get(dkey, {}).get(dname, dkey)
                label = sname if sname not in ("Out", "Out1") else ""
                if dname in JOURNAL_STATES:  # journal nodes: which state the entry gets
                    label = f"{label} → {dname}" if label else f"→ {dname}"
                g.link(skey, dkey, label)


def scene_graph(g: Graph, scene: J, h: Handles, loc: dict[str, str]) -> None:
    graph = h.get(scene["sceneGraph"])["graph"]
    options = {
        o["itemId"]["id"]: o["locstringId"]["ruid"]
        for o in scene.get("screenplayStore", {}).get("options", [])
    }
    for raw in graph:
        n = h.get(raw)
        nid = n["nodeId"]["id"]
        t = n["$type"]
        key = str(nid)
        labels: dict[tuple[int, int], str] = {}
        if t == "scnStartNode":
            kind, label = "start", "scene start"
        elif t == "scnEndNode":
            kind, label = "end", "scene end"
        elif t == "scnHubNode":
            kind, label = "hub", ""
        elif t == "scnRandomizerNode":
            kind, label = "decision", "random"
        elif t == "scnSectionNode":
            kind, label = "section", section(n, scene, h)
        elif t == "scnChoiceNode":
            kind, label = "choice", "player choice"
            for i, o in enumerate(n.get("options", [])):
                ruid = options.get(obj(o.get("screenplayOptionId")).get("id"), "")
                caption = loc.get(ruid, f"option {i}")
                if o.get("questCondition"):
                    caption += "\nshown if " + cond_text(o["questCondition"], h)
                labels[(0, i)] = caption
        elif t == "scnQuestNode":
            kind, label = quest_node(h.get(n["questNode"]), h)
            for i, name in enumerate(n.get("osockMappings", [])):
                if value(name) not in ("Out", "Out1"):
                    labels[(0, i)] = str(value(name))
        else:
            kind, label = "action", short_type(t)
        g.add(Node(key, kind, f"{label}\n[{nid}]" if label else str(nid)))
        for s in n.get("outputSockets", []):
            stamp = (s["stamp"]["name"], s["stamp"]["ordinal"])
            label = labels.get(stamp, "" if stamp == (0, 0) else f"#{stamp[0]}.{stamp[1]}")
            for d in s.get("destinations", []):
                g.link(key, str(d["nodeId"]["id"]), label)


def load_loc(paths: list[Path]) -> dict[str, str]:
    """String id -> text, from WolvenKit JSON of subtitle or onscreen files."""
    out: dict[str, str] = {}
    for p in paths:
        stack: list[J] = [json.loads(p.read_text())]
        while stack:
            o = stack.pop()
            if is_dict(o):
                sid = o.get("stringId") or o.get("primaryKey")
                text = o.get("femaleVariant") or o.get("maleVariant")
                if sid and text:
                    out[str(sid)] = str(text)
                stack += list(o.values())
            elif is_list(o):
                stack += o
    return out


def build(doc: J, loc: dict[str, str]) -> Graph:
    h = Handles(doc)
    root = doc["Data"]["RootChunk"]
    g = Graph()
    if root["$type"] in ("questQuestPhaseResource", "questQuestResource"):
        questphase_graph(g, h.get(root["graph"]), h, "", "")
    elif root["$type"] == "scnSceneResource":
        scene_graph(g, root, h, loc)
    else:
        raise ValueError(f"not a quest, questphase or scene: {root['$type']}")
    return g


def reachable(g: Graph, start: list[str], stop: set[str]) -> Graph:
    succ: dict[str, list[str]] = defaultdict(list)
    for e in g.edges:
        succ[e.src].append(e.dst)
    keep: set[str] = set()
    todo = list(start)
    while todo:
        k = todo.pop()
        if k in keep or k not in g.nodes:
            continue
        keep.add(k)
        if k not in stop:
            todo += succ[k]
    out = Graph(clusters=g.clusters)
    for k in keep:
        out.add(g.nodes[k])
    out.edges = [e for e in g.edges if e.src in keep and e.dst in keep]
    return out


def fold(g: Graph) -> Graph:
    """Merge nodes with the same shape, neighbours and label up to names/numbers."""

    def sig(n: Node) -> tuple[str, str, frozenset[tuple[str, str]], frozenset[tuple[str, str]]]:
        body = re.sub(r"\[\d+\]$", "", n.label)
        body = re.sub(r"[\w.]*\d[\w.]*|Items\.\w+", "*", body)
        preds = frozenset((e.src, e.label) for e in g.edges if e.dst == n.key)
        succs = frozenset((e.dst, e.label) for e in g.edges if e.src == n.key)
        return n.kind, body, preds, succs

    groups: dict[tuple[str, str, frozenset[tuple[str, str]], frozenset[tuple[str, str]]], list[str]]
    groups = defaultdict(list)
    for n in g.nodes.values():
        groups[sig(n)].append(n.key)
    alias: dict[str, str] = {}
    out = Graph(clusters=g.clusters)
    for keys in groups.values():
        first = g.nodes[keys[0]]
        extra = f"\n(+{len(keys) - 1} similar)" if len(keys) > 1 else ""
        out.add(Node(first.key, first.kind, first.label + extra, first.cluster))
        for k in keys:
            alias[k] = first.key
    for e in g.edges:
        out.link(alias[e.src], alias[e.dst], e.label)
    return out


def quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def back_edges(g: Graph, roots: list[str]) -> set[tuple[str, str]]:
    """Edges that close a loop in a depth-first walk from the roots."""
    succ: dict[str, list[str]] = defaultdict(list)
    for e in g.edges:
        succ[e.src].append(e.dst)
    has_pred = {e.dst for e in g.edges}
    order = roots + sorted(k for k in g.nodes if k not in has_pred) + sorted(g.nodes)
    state: dict[str, int] = {}  # 1 = on the current path, 2 = done
    back: set[tuple[str, str]] = set()
    for root in order:
        if root in state or root not in g.nodes:
            continue
        stack = [(root, iter(succ[root]))]
        state[root] = 1
        while stack:
            k, it = stack[-1]
            nxt = next(it, None)
            if nxt is None:
                state[k] = 2
                stack.pop()
            elif state.get(nxt) == 1:
                back.add((k, nxt))
            elif nxt not in state:
                state[nxt] = 1
                stack.append((nxt, iter(succ[nxt])))
    return back


def to_dot(g: Graph, title: str, roots: list[str] | None = None) -> str:
    lines = [
        "digraph quest {",
        f"  label={quote(title)}; labelloc=t; fontname=Helvetica; fontsize=14;",
        "  rankdir=TB; nodesep=0.35; ranksep=0.45;",
        '  node [fontname=Helvetica fontsize=10 margin="0.15,0.06"];',
        '  edge [fontname=Helvetica fontsize=9 color="#555555" fontcolor="#333333"];',
    ]
    children: dict[str, list[str]] = defaultdict(list)
    for key, (_, parent) in g.clusters.items():
        children[parent].append(key)
    members: dict[str, list[Node]] = defaultdict(list)
    for n in g.nodes.values():
        members[n.cluster if n.cluster in g.clusters else ""].append(n)

    def emit(cluster: str, indent: str) -> None:
        for n in members[cluster]:
            lines.append(f"{indent}{quote(n.key)} [label={quote(n.label)} {STYLE[n.kind]}];")
        for c in children[cluster]:
            if not any(members[x] for x in [c, *children[c]]):
                continue
            lines.append(f"{indent}subgraph {quote('cluster_' + c)} {{")
            lines.append(f'{indent}  label={quote(g.clusters[c][0])}; style="rounded,dashed";')
            lines.append(f'{indent}  color="#999999"; fontsize=10;')
            emit(c, indent + "  ")
            lines.append(f"{indent}}}")

    emit("", "  ")
    back = back_edges(g, roots or [])
    for e in g.edges:
        attrs = [f"label={quote(e.label)}"] if e.label else []
        if (e.src, e.dst) in back:
            attrs += ["style=dashed", "constraint=false"]
        attr = f" [{' '.join(attrs)}]" if attrs else ""
        lines.append(f"  {quote(e.src)} -> {quote(e.dst)}{attr};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("file", type=Path)
    ap.add_argument("-o", "--out", type=Path)
    ap.add_argument("--from", dest="start", nargs="+", default=[])
    ap.add_argument("--stop", nargs="+", default=[])
    ap.add_argument("--loc", nargs="+", type=Path, default=[])
    ap.add_argument("--fold", action="store_true")
    args = ap.parse_args(argv)
    g = build(json.loads(args.file.read_text()), load_loc(args.loc))
    if args.start:
        g = reachable(g, args.start, set(args.stop))
    if args.fold:
        g = fold(g)
    dot = to_dot(g, args.file.name.removesuffix(".json"), args.start)
    if args.out is None:
        sys.stdout.write(dot)
    elif args.out.suffix == ".dot":
        args.out.write_text(dot)
    else:
        fmt = args.out.suffix.lstrip(".")
        subprocess.run(["dot", f"-T{fmt}", "-o", str(args.out)], input=dot, text=True, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
