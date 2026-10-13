#!/usr/bin/env python3
"""Verify preserved inputs against the preservation-stage manifests."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    checked = 0
    failures = []

    def verify(path, expected):
        nonlocal checked
        checked += 1
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            failures.append(str(path.relative_to(ROOT)))

    original = ROOT / "original"
    for item in json.loads((original / "analysis/archive-manifest.json").read_text())["archives"]:
        verify(original / "archives" / item["filename"], item["sha256"])
    mirror = json.loads((original / "additional-files/mirrors/download-manifest.json").read_text())
    verify(ROOT / mirror["saved_path"], mirror["sha256"])
    verify(original / "additional-files/official/offline.dat", "fc524160b2ab4e7f77eefecba7ee2b7dd0267c7e88c9a78c0418b4c5a6d42a13")
    for item in json.loads((original / "analysis/inventory.json").read_text()):
        verify(original / "game-files/ipa-1.14" / item["path"], item["sha256"])
    later = json.loads((original / "analysis/ipa-1.27-inventory.json").read_text())
    if isinstance(later, list):
        for item in later:
            verify(original / "game-files/ipa-1.27" / item["path"], item["sha256"])
    for item in json.loads((original / "analysis/download-manifest.json").read_text())["assets"]:
        verify(ROOT / item["path"], item["sha256"])
        if item["kind"] == "level-pack":
            pack = Path(item["path"]).stem
            for entry in item["files"]:
                verify(original / "game-files/downloaded-packs" / pack / entry["path"], entry["sha256"])
    result = {"checks": checked, "failures": failures, "source": "preservation-stage manifests", "originals_modified": bool(failures)}
    (ROOT / "builds/original-integrity.json").write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result))
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
