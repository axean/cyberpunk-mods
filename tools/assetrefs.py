#!/usr/bin/env python3
"""Check which resources an unpacked mod references: vanilla, its own, or neither.

    assetrefs.py <mod dir> <metadata-resources.csv> [-v]

<mod dir> holds `raw/` (from `tools/wk unbundle`) and `json/` (from `tools/wk convert
serialize`). <metadata-resources.csv> is CDPR's list of game resource paths, shipped in
REDmod's `REDmodPlugin_updated.zip` (Metadata/<version>/). It is not part of this repo.

A reference counts as "own" if the mod ships that path, "vanilla" if the game list has it,
and "neither" otherwise (newer game files, generated lipsync, or missing resources).
-v lists the "neither" paths.
"""

import re
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

# Depot paths inside WolvenKit JSON strings: "base\\...\\file.ext" or "ep1\\..."
DEPOT_PATH = re.compile(r'"((?:base|ep1)\\\\[^"]+\.[a-z0-9_]+)"', re.IGNORECASE)


@dataclass(frozen=True)
class Refs:
    vanilla: set[str]
    own: set[str]
    neither: set[str]

    @property
    def total(self) -> int:
        return len(self.vanilla) + len(self.own) + len(self.neither)


def norm(path: str) -> str:
    return path.replace("/", "\\").lower()


def load_vanilla(csv: Path) -> set[str]:
    """Resource paths from metadata-resources.csv (`path,hash` per line)."""
    with csv.open(errors="ignore") as fh:
        return {norm(line.split(",", 1)[0]) for line in fh if line.strip()}


def own_files(raw: Path) -> set[str]:
    return {norm(str(p.relative_to(raw))) for p in raw.rglob("*") if p.is_file()}


def referenced(json_dir: Path) -> set[str]:
    refs: set[str] = set()
    for f in json_dir.glob("*.json"):
        text = f.read_text(errors="ignore")
        refs.update(norm(m.replace("\\\\", "\\")) for m in DEPOT_PATH.findall(text))
    return refs


def classify(refs: Iterable[str], vanilla: set[str], own: set[str]) -> Refs:
    out = Refs(set(), set(), set())
    for r in refs:
        (out.own if r in own else out.vanilla if r in vanilla else out.neither).add(r)
    return out


def extensions(paths: Iterable[str]) -> list[str]:
    return sorted({p.rsplit(".", 1)[-1] for p in paths})


def main(argv: list[str]) -> int:
    args = [a for a in argv if a != "-v"]
    if len(args) != 2:
        print(__doc__)
        return 2
    mod, csv = Path(args[0]), Path(args[1])
    refs = classify(referenced(mod / "json"), load_vanilla(csv), own_files(mod / "raw"))
    print(f"{refs.total} referenced paths")
    print(f"  vanilla {len(refs.vanilla):6}  {' '.join(extensions(refs.vanilla))}")
    print(f"  own     {len(refs.own):6}  {' '.join(extensions(refs.own))}")
    print(f"  neither {len(refs.neither):6}  {' '.join(extensions(refs.neither))}")
    if "-v" in argv:
        for p in sorted(refs.neither):
            print(f"    {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
