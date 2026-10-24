from pathlib import Path

import assetrefs


def test_referenced_finds_escaped_depot_paths(tmp_path: Path) -> None:
    (tmp_path / "a.scene.json").write_text(
        '{"DepotPath": {"$value": "base\\\\anims\\\\Smoke.anims"}, "x": "ep1\\\\q\\\\b.ent"}'
    )
    assert assetrefs.referenced(tmp_path) == {"base\\anims\\smoke.anims", "ep1\\q\\b.ent"}


def test_classify_prefers_own_over_vanilla() -> None:
    refs = {"base\\a.mesh", "base\\b.scene", "base\\c.anims"}
    out = assetrefs.classify(refs, vanilla={"base\\a.mesh", "base\\b.scene"}, own={"base\\b.scene"})
    assert out.vanilla == {"base\\a.mesh"}
    assert out.own == {"base\\b.scene"}
    assert out.neither == {"base\\c.anims"}
    assert out.total == 3


def test_load_vanilla_and_own_files(tmp_path: Path) -> None:
    csv = tmp_path / "metadata-resources.csv"
    csv.write_text("base\\A.mesh,123\nbase\\b.ent,456\n")
    raw = tmp_path / "raw" / "base" / "quest"
    raw.mkdir(parents=True)
    (raw / "My.questphase").write_bytes(b"")
    assert assetrefs.load_vanilla(csv) == {"base\\a.mesh", "base\\b.ent"}
    assert assetrefs.own_files(tmp_path / "raw") == {"base\\quest\\my.questphase"}
