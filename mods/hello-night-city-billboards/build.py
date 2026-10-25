#!/usr/bin/env python3
"""Generate hello-night-city-billboards: Mr. Stud's billboard ads say "HELLO NIGHT CITY -AA".
Run through tools/build-mod.sh.

    build.py <out dir>

Patches the ad widgets from the player's own game at build time (never committed): in every
screen-shape layout the images are replaced by one text widget over the dark background.
"""

import json
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
import devstatus  # noqa: E402
import gamefiles  # noqa: E402
import wkjson as wk  # noqa: E402

ARCHIVE = "hello_night_city_billboards"
DIR = rf"base\{ARCHIVE}"
JOURNAL = rf"{DIR}\{ARCHIVE}.journal"
ONSCREENS = rf"{DIR}\{ARCHIVE}_en-us.json"
WIDGETS = [
    r"base\gameplay\gui\world\adverts\mrstud\mrstud.inkwidget",
    r"base\gameplay\gui\world\adverts\mr_stud\mr_stud.inkwidget",
]
FONT = r"base\gameplay\gui\fonts\orbitron\orbitron.inkfontfamily"
PINK = (1.0, 0.25, 0.625)  # exact in float32, so the round-trip check stays exact


def vec2(x: float, y: float) -> dict[str, Any]:
    return {"$type": "Vector2", "X": x, "Y": y}


def margin() -> dict[str, Any]:
    return {"$type": "inkMargin", "bottom": 0, "left": 0, "right": 0, "top": 0}


def text_widget(parent: wk.Handle, width: float, height: float, flags: str) -> wk.Handle:
    """Text filling the whole canvas, centred; one word per line on tall screens."""
    tall = height > width
    text = "HELLO\nNIGHT\nCITY\n-AA" if tall else "HELLO NIGHT CITY\n-AA"
    size = min(width / 4.5, height / 6) if tall else min(width / 12, height / 3)
    return wk.Handle(
        {
            "$type": "inkTextWidget",
            "affectsLayoutWhenHidden": 0,
            "aligmentConverted": 0,
            "backendData": None,
            "canSupportFocus": 0,
            "contentHAlign": "Fill",
            "contentVAlign": "Fill",
            "effects": [],
            "fitToContent": 0,
            "font": None,
            "fontFamily": wk.resource(FONT, flags),
            "fontSize": round(size),
            "fontStyle": wk.cname("Medium"),
            "isInteractive": 0,
            "justification": "Center",
            "layout": {
                "$type": "inkWidgetLayout",
                "anchor": "TopLeft",
                "anchorPoint": vec2(0, 0),
                "HAlign": "Fill",
                "margin": margin(),
                "padding": margin(),
                "sizeCoefficient": 1,
                "sizeRule": "Fixed",
                "VAlign": "Fill",
            },
            "letterCase": "OriginalCase",
            "lineHeightPercentage": 1,
            "localizationString": {"unk1": "0", "value": ""},
            "lockFontInGame": 0,
            "logicController": None,
            "name": wk.cname("hello_night_city"),
            "opacity": 1,
            "parentWidget": parent,
            "propertyManager": None,
            "renderTransform": {
                "$type": "inkUITransform",
                "rotation": 0,
                "scale": vec2(1, 1),
                "shear": vec2(0, 0),
                "translation": vec2(0, 0),
            },
            "renderTransformPivot": vec2(0.5, 0.5),
            "scrollDelay": 30,
            "scrollTextSpeed": 0.25,
            "secondaryControllers": [],
            "size": vec2(width, height),
            "state": wk.cname("Default"),
            "style": None,
            "text": text,
            "textHorizontalAlignment": "Center",
            "textIdKey": wk.cname("None"),
            "textOverflowPolicy": "None",
            "textVerticalAlignment": "Center",
            "tintColor": {
                "$type": "HDRColor",
                "Alpha": 1,
                "Blue": PINK[2],
                "Green": PINK[1],
                "Red": PINK[0],
            },
            "tracking": 1,
            "userData": [],
            "visible": 1,
            "wrappingInfo": {
                "$type": "textWrappingInfo",
                "autoWrappingEnabled": 0,
                "forceMinimumWidthToWrappingAtPosition": 0,
                "wrappingAtPosition": 0,
                "wrappingPolicy": "Default",
            },
        }
    )


def patch(canvas: wk.Handle, flags: str) -> None:
    """Keep the background rectangle, put our text in front of it (children draw last-first).
    flags: resource flags for the font; the cooked copy (packageData) stores none."""
    children = canvas.data["children"].data["children"]
    background = [c for c in children if c.data["$type"] == "inkRectangleWidget"][:1]
    size = canvas.data["size"]
    children[:] = [text_widget(canvas, size["X"], size["Y"], flags), *background]


def main() -> None:
    out = Path(sys.argv[1])
    for path in WIDGETS:
        root = wk.decode(gamefiles.resource_json(path)["Data"]["RootChunk"])
        for item in root["libraryItems"]:
            if item["name"]["$value"] == "Root":
                continue
            patch(item["package"]["Data"]["File"]["RootChunk"]["rootWidget"], "Soft")
            patch(item["packageData"]["Data"]["Chunks"][0]["rootWidget"], "Default")
        wk.write(out / "json", path, root)

    chat, texts = devstatus.register(
        "hello-night-city-billboards", f"billboards loaded, {devstatus.stamp(HERE)}"
    )
    wk.write(out / "json", JOURNAL, wk.journal([wk.folder("contacts/unknown", [chat])]))
    wk.write(out / "json", ONSCREENS, wk.onscreens(texts))
    config = {"journal": [JOURNAL], "localization": {"onscreens": {"en-us": ONSCREENS}}}
    archive = out / "mod" / "archive"
    archive.mkdir(parents=True, exist_ok=True)
    (archive / f"{ARCHIVE}.archive.json").write_text(json.dumps(config, indent=4) + "\n")
    (archive / f"{ARCHIVE}.archive.xl").write_text(
        f"journal:\n  - {JOURNAL}\nlocalization:\n  onscreens:\n    en-us: {ONSCREENS}\n"
    )
    about = {"ModInfo": {"ModName": "hello-night-city-billboards", "ModID": -1}}
    (out / "mod" / "about.json").write_text(json.dumps(about, indent=4) + "\n")


if __name__ == "__main__":
    main()
