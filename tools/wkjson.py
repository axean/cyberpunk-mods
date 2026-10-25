#!/usr/bin/env python3
"""Build WolvenKit JSON from Python, as input for `tools/wk convert deserialize`.

Objects wrapped in `Handle` are shared by identity: the first time one is written it gets a
HandleId, later uses become HandleRefId. Quest graphs need this, since sockets and the
connections between them point at each other.

Field values not set by a mod (flags, platform, streaming defaults) are the ones WolvenKit
writes when it serializes working game files.
"""

import json
import struct
import sys
from base64 import b64encode
from collections.abc import Sequence
from pathlib import Path
from typing import Any, cast

J = Any  # a WolvenKit JSON value

HEADER = {
    "WolvenKitVersion": "10.0.0-beta.1",
    "WKitJsonVersion": "0.0.9",
    "GameVersion": 2500,
    "ExportedDateTime": "2026-01-01T00:00:00Z",
    "DataType": "CR2W",
    "ArchiveFileName": "",
}


class Handle:
    def __init__(self, data: dict[str, J]) -> None:
        self.data = data


def encode(o: J, ids: dict[int, str]) -> J:
    if isinstance(o, Handle):
        if id(o) in ids:
            return {"HandleRefId": ids[id(o)]}
        ids[id(o)] = str(len(ids))
        return {"HandleId": ids[id(o)], "Data": encode(o.data, ids)}
    if isinstance(o, dict):
        return {k: encode(v, ids) for k, v in cast(dict[str, J], o).items()}
    if isinstance(o, list):
        return [encode(v, ids) for v in cast(list[J], o)]
    return o


def document(root: dict[str, J]) -> dict[str, J]:
    data: dict[str, J] = {
        "Version": 195,
        "BuildVersion": 0,
        "RootChunk": encode(root, {}),
        "EmbeddedFiles": [],
    }
    return {"Header": HEADER, "Data": data}


def same(a: Path, b: Path) -> bool:
    """True if two WolvenKit JSON files hold the same resource (headers ignored)."""
    return json.loads(a.read_text())["Data"] == json.loads(b.read_text())["Data"]


def write(out_dir: Path, depot_path: str, root: dict[str, J]) -> Path:
    """Write `root` as <out_dir>/<depot path>.json (backslashes become folders)."""
    path = out_dir / (depot_path.replace("\\", "/") + ".json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(document(root), indent=2) + "\n")
    return path


def cname(s: str) -> dict[str, str]:
    return {"$type": "CName", "$storage": "string", "$value": s}


def resource(path: str | None, flags: str = "Soft") -> dict[str, J]:
    value = {"$type": "ResourcePath", "$storage": "string", "$value": path}
    if path is None:
        value = {"$type": "ResourcePath", "$storage": "uint64", "$value": "0"}
    return {"DepotPath": value, "Flags": flags}


def fnv1a64(s: str) -> int:
    h = 0xCBF29CE484222325
    for b in s.encode():
        h = ((h ^ b) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return h


def loc_key(secondary_key: str) -> int:
    """Primary key for an onscreen string: a hash of its secondary key, kept below 2**63."""
    return fnv1a64(secondary_key) & 0x7FFFFFFFFFFFFFFF


def loc_string(secondary_key: str) -> dict[str, str]:
    return {"unk1": "0", "value": f"LocKey#{loc_key(secondary_key)}"}


# Quest graphs (.questphase)


class Node:
    def __init__(self, type_: str, id_: int, sockets: list[tuple[str, str]], **fields: J) -> None:
        self.sockets = {
            name: Handle(
                {
                    "$type": "questSocketDefinition",
                    "connections": [],
                    "name": cname(name),
                    "type": kind,
                }
            )
            for name, kind in [("CutDestination", "CutDestination"), *sockets]
        }
        data = {"id": id_, "sockets": [*self.sockets.values()], **fields}
        self.handle = Handle({"$type": type_} | dict(sorted(data.items())))  # WolvenKit's order


class Graph:
    def __init__(self) -> None:
        self.nodes: list[Node] = []

    def add(self, node: Node) -> Node:
        self.nodes.append(node)
        return node

    def connect(self, src: Node, dst: Node, out: str = "Out", into: str = "In") -> None:
        s, d = src.sockets[out], dst.sockets[into]
        c = Handle({"$type": "graphGraphConnectionDefinition", "destination": d, "source": s})
        s.data["connections"].append(c)
        d.data["connections"].append(c)

    def phase(self) -> dict[str, J]:
        graph = Handle({"$type": "questGraphDefinition", "nodes": [n.handle for n in self.nodes]})
        return {
            "$type": "questQuestPhaseResource",
            "cookingPlatform": "PLATFORM_PC",
            "graph": graph,
            "inplacePhases": [],
            "phasePrefabs": [],
        }


def input_node(id_: int, name: str = "In1") -> Node:
    return Node("questInputNodeDefinition", id_, [("Out", "Output")], socketName=cname(name))


def output_node(id_: int, name: str = "Out1") -> Node:
    return Node(
        "questOutputNodeDefinition",
        id_,
        [("In", "Input")],
        socketName=cname(name),
        type="Terminating",
    )


def fact_is(fact: str, comparison: str, value: int) -> Handle:
    """FactsDB condition; comparison is Equal, NotEqual, Greater, GreaterOrEqual, Less, ..."""
    cmp = {
        "$type": "questVarComparison_ConditionType",
        "comparisonType": comparison,
        "factName": fact,
        "value": value,
    }
    return Handle({"$type": "questFactsDBCondition", "type": Handle(cmp)})


def condition_node(id_: int, condition: Handle) -> Node:
    """Branch once: True or False."""
    sockets = [("In", "Input"), ("True", "Output"), ("False", "Output")]
    return Node("questConditionNodeDefinition", id_, sockets, condition=condition)


def pause_node(id_: int, condition: Handle) -> Node:
    """Wait until the condition holds."""
    sockets = [("In", "Input"), ("Out", "Output")]
    return Node("questPauseConditionNodeDefinition", id_, sockets, condition=condition)


def set_fact_node(id_: int, fact: str, value: int) -> Node:
    setvar = {"$type": "questSetVar_NodeType", "factName": fact, "setExactValue": 1, "value": value}
    sockets = [("In", "Input"), ("Out", "Output")]
    return Node("questFactsDBManagerNodeDefinition", id_, sockets, type=Handle(setvar))


def journal_node(id_: int, path: str, class_name: str, notify: bool = True) -> Node:
    """Set a journal entry's state: connect into its "Active" or "Inactive" socket."""
    jpath = {
        "$type": "gameJournalPath",
        "className": cname(class_name),
        "editorPath": "",
        "fileEntryIndex": 1,
        "realPath": path,
    }
    entry = {
        "$type": "questJournalEntry_NodeType",
        "path": Handle(jpath),
        "sendNotification": int(notify),
    }
    sockets = [("Active", "Input"), ("Inactive", "Input"), ("Out", "Output")]
    return Node("questJournalNodeDefinition", id_, sockets, type=Handle(entry))


# Journal (.journal)


def journal(entries: list[Handle]) -> dict[str, J]:
    root = {
        "$type": "gameJournalRootFolderEntry",
        "descriptor": resource(None),
        "entries": entries,
        "id": "",
        "journalEntryOverrideDataList": [],
    }
    return {"$type": "gameJournalResource", "cookingPlatform": "PLATFORM_PC", "entry": Handle(root)}


def folder(id_: str, entries: list[Handle]) -> Handle:
    """A folder merged into the game's journal by id, e.g. "contacts/<contact>"."""
    return Handle(
        {
            "$type": "gameJournalFolderEntry",
            "entries": entries,
            "id": id_,
            "journalEntryOverrideDataList": [],
        }
    )


def conversation(id_: str, title_key: str, entries: list[Handle]) -> Handle:
    return Handle(
        {
            "$type": "gameJournalPhoneConversation",
            "entries": entries,
            "id": id_,
            "journalEntryOverrideDataList": [],
            "title": loc_string(title_key),
        }
    )


def message(id_: str, text_key: str, sender: str = "NPC", delay: int = 3) -> Handle:
    return Handle(
        {
            "$type": "gameJournalPhoneMessage",
            "attachment": None,
            "delay": delay,
            "id": id_,
            "imageId": {"$type": "TweakDBID", "$storage": "uint64", "$value": "0"},
            "isQuestImportant": 0,
            "journalEntryOverrideDataList": [],
            "sender": sender,
            "text": loc_string(text_key),
        }
    )


# Localization (onscreens .json)


def onscreens(texts: dict[str, str]) -> dict[str, J]:
    """Onscreen strings by secondary key, referenced with loc_string(key)."""
    entries = [
        {
            "$type": "localizationPersistenceOnScreenEntry",
            "femaleVariant": text,
            "maleVariant": "",
            "primaryKey": str(loc_key(key)),
            "secondaryKey": key,
        }
        for key, text in texts.items()
    ]
    root = {"$type": "localizationPersistenceOnScreenEntries", "entries": entries}
    return {"$type": "JsonResource", "cookingPlatform": "PLATFORM_PC", "root": Handle(root)}


# World (.streamingsector, .streamingblock)


def _vec3(x: float, y: float, z: float) -> dict[str, J]:
    return {"$type": "Vector3", "X": x, "Y": y, "Z": z}


def _outline(points: Sequence[tuple[float, float]], height: float) -> Handle:
    buffer = struct.pack("<I", len(points))
    for x, y in points:
        buffer += struct.pack("<4f", x, y, 0, 1)
    buffer += struct.pack("<f", height)
    return Handle(
        {
            "$type": "AreaShapeOutline",
            "buffer": b64encode(buffer).decode(),
            "height": height,
            "points": [_vec3(x, y, 0) for x, y in points],
        }
    )


def trigger_sector(
    node_ref: str, node_id: int, scale: tuple[float, float, float], debug_name: str
) -> dict[str, J]:
    """Always-loaded sector with one quest trigger area: a unit square at the world origin,
    scaled by `scale` (metres). Quests test "player is inside <node_ref>"."""
    square = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    notifier = {
        "$type": "questTriggerNotifier_Quest",
        "excludeChannels": 0,
        "includeChannels": "TC_Default",
        "isEnabled": 1,
    }
    node = {
        "$type": "worldTriggerAreaNode",
        "color": {"$type": "Color", "Alpha": 128, "Blue": 160, "Green": 160, "Red": 255},
        "debugName": cname(debug_name),
        "isHostOnly": 0,
        "isVisibleInGame": 1,
        "notifiers": [Handle(notifier)],
        "outline": _outline(square, 2),
        "proxyScale": None,
        "sourcePrefabHash": "0",
        "tag": "None",
        "tagExt": "None",
    }
    setup = {
        "$type": "worldCompiledNodeInstanceSetupInfo",
        "dataGroup": "Base",
        "externalInplaceResourceHash": resource(None, "Default"),
        "globalNodeId": {"$type": "worldGlobalNodeID", "hash": str(node_id)},
        "instanceIndex": 0,
        "nodeFlags": (
            "FLAG_BoostedToPrefabDistance, FLAG_AllowForceStreamIn, FLAG_IsInterior, "
            "FLAG_NoCollision, FLAG_PrefabProxyMesh, FLAG_Building, FLAG_Decoration, FLAG_Road, "
            "FLAG_Terrain, FLAG_VisualFluff, FLAG_IsExludedOnConsole, FLAG_Culling_IsCullable, "
            "FLAG_GlobalIllumination, FLAG_AllowDistanceBoosting"
        ),
        "nodeIdx": "524287",
        "patchedNode": {"$type": "NodeRef", "$storage": "uint64", "$value": "0"},
        "preboostStreamingRefPoint": _vec3(0, 0, 0),
        "proxyMeshId": {"$type": "worldGlobalNodeID", "hash": "0"},
        "scale": _vec3(*scale),
        "secondaryRefPointDistance": 2.93873588e-38,
        "secondaryRefPointPosition": _vec3(0, 0, 0),
        "streamingDistance": 9.14767638e-41,
        "streamingPriority": "50",
        "streamingRefPoint": _vec3(0, 0, 0),
        "todvisMask": "16879",
        "transform": {
            "$type": "Transform",
            "orientation": {"$type": "Quaternion", "i": 0, "j": 0, "k": 0, "r": 1},
            "position": {"$type": "Vector4", "W": 0, "X": 0, "Y": 0, "Z": 0},
        },
    }
    return {
        "$type": "worldStreamingSector",
        "category": "AlwaysLoaded",
        "cookingPlatform": "PLATFORM_PC",
        "externInplaceResource": resource(None),
        "level": 0,
        "localInplaceResource": [],
        "nodeData": {
            "BufferId": "0",
            "Flags": 4063232,
            "Type": (
                "WolvenKit.RED4.Archive.Buffer.worldNodeDataBuffer, WolvenKit.RED4, "
                "Version=10.0.0.0, Culture=neutral, PublicKeyToken=null"
            ),
            "Data": [setup],
        },
        "nodeRefs": [{"$type": "NodeRef", "$storage": "string", "$value": node_ref}],
        "nodes": [Handle(node)],
        "persistentNodeIndex": 0,
        "persistentNodes": [dict(setup)],
        "variantIndices": [0],
        "variantNodes": [],
        "version": 62,
    }


def streaming_block(sectors: list[str]) -> dict[str, J]:
    """Block listing always-loaded sectors (the whole world as streaming box)."""
    big = 3.40282347e38
    index = {"$type": "worldStreamingBlockIndex", "oup": "Base", "rldGridCell": 0}
    descriptors: list[J] = [
        {
            "$type": "worldStreamingSectorDescriptor",
            "blockIndex": dict(index),
            "category": "AlwaysLoaded",
            "data": resource(path),
            "level": 0,
            "numNodeRanges": 1,
            "questPrefabNodeRef": {"$type": "NodeRef", "$storage": "uint64", "$value": "0"},
            "streamingBox": {
                "$type": "Box",
                "Max": {"$type": "Vector4", "W": big, "X": big, "Y": big, "Z": big},
                "Min": {"$type": "Vector4", "W": -big, "X": -big, "Y": -big, "Z": -big},
            },
            "variants": [],
        }
        for path in sectors
    ]
    return {
        "$type": "worldStreamingBlock",
        "cookingPlatform": "PLATFORM_PC",
        "descriptors": descriptors,
        "index": index,
    }


def main() -> None:
    """wkjson.py same <a.json> <b.json>: exit 1 if the resources differ."""
    if sys.argv[1:2] != ["same"] or len(sys.argv) != 4:
        sys.exit(main.__doc__)
    sys.exit(0 if same(Path(sys.argv[2]), Path(sys.argv[3])) else 1)


if __name__ == "__main__":
    main()
