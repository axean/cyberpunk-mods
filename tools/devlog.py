#!/usr/bin/env python3
"""Work with dev-log captures from Cyberpunk 2077 (mods/dev-log, JSONL).

    devlog.py crop <dev_log.jsonl> <dataset.jsonl>

crop drops standstill lines (V's position, camera rotation and locomotion state unchanged since
the previous kept line). Marker lines ({"t", "mark"}) are always kept.
"""

import json
import sys
from pathlib import Path
from typing import Any


def crop(lines: list[str]) -> list[str]:
    kept: list[str] = []
    previous: tuple[Any, ...] | None = None
    for line in lines:
        row = json.loads(line)
        if "mark" in row:
            kept.append(line)
            continue
        signature = (row["pos"], row.get("cam_rot"), row["locomotion"])
        if signature != previous:
            kept.append(line)
            previous = signature
    return kept


def main() -> None:
    if len(sys.argv) != 4 or sys.argv[1] != "crop":
        sys.exit(__doc__)
    source, dest = Path(sys.argv[2]), Path(sys.argv[3])
    kept = crop(source.read_text().splitlines(keepends=True))
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("".join(kept))
    print(f"{dest}: {len(kept)} lines")


if __name__ == "__main__":
    main()
