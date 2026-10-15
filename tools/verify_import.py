#!/usr/bin/env python3
"""Independently re-convert every image/audio source without replacing runtime files."""
import hashlib
import importlib.util
import io
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    spec = importlib.util.spec_from_file_location("original_importer", ROOT / "tools/importers/import_original.py")
    importer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(importer)
    manifest = json.loads((ROOT / "game/data/import_manifest.json").read_text())
    checks = 0
    failures = []
    with tempfile.TemporaryDirectory(prefix="spice-import-check-", dir=ROOT / "builds") as directory:
        for asset in manifest["assets"]:
            if "runtime" not in asset:
                continue
            source = ROOT / asset["selected"]
            checks += 1
            if source.suffix.lower() in (".png", ".jpg", ".jpeg"):
                buffer = io.BytesIO()
                importer.decode(source).save(buffer, format="PNG", compress_level=6)
                digest = hashlib.sha256(buffer.getvalue()).hexdigest()
            elif source.suffix.lower() == ".caf":
                destination = Path(directory) / "decoded.wav"
                subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(source), str(destination)], check=True)
                digest = importer.sha(destination)
                destination.unlink()
            elif source.suffix.lower() == '.mov':
                destination = Path(directory) / 'converted.ogv'
                importer.convert_movie(source, destination)
                digest = importer.sha(destination)
                destination.unlink()
            else:
                digest = importer.sha(source)
            if digest != asset["runtime_sha256"]:
                failures.append(asset["logical_path"])
            if checks % 250 == 0:
                print("Re-converted", checks, "assets", flush=True)
    result = {"checks": checks, "failures": failures, "method": "independent full image, CAF and publisher movie re-conversion; no cached output reused"}
    (ROOT / "builds/import-verification.json").write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result))
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
