#!/usr/bin/env python3
"""Deterministically derive Godot content. Never writes beneath original/."""
import argparse
import hashlib
import io
import json
import posixpath
import re
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zlib
from collections import defaultdict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ROOT / "original"
IPA = ORIGINAL / "game-files/ipa-1.14/Payload/Tower.app"
GAME = ROOT / "game"
OUT = GAME / "assets"
DATA = GAME / "data"
sys.path.insert(0, str(ROOT / "tools"))
from inspect_nib import decode as decode_nib


def menu_layout():
    """Retain authored iPad geometry and view order for the desktop adapter."""
    nib = decode_nib(IPA / "TowerViewController.nib")
    objects = nib['objects']
    outlets = {}
    for obj in objects:
        if obj['class'] == 'UIRuntimeOutletConnection':
            p = obj['properties']
            name = objects[p['UILabel']['ref']]['properties']['NS.bytes']
            outlets[p['UIDestination']['ref']] = name
    entries = []

    def walk(index, offset=(0, 0), ancestors=()):
        obj = objects[index]
        p = obj['properties']
        b, c = p.get('UIBounds', [0, 0, 0, 0]), p.get('UICenter', [0, 0])
        pos = [offset[0]+c[0]-b[2]/2, offset[1]+c[1]-b[3]/2]
        entry = {'id': index, 'outlet': outlets.get(index, ''), 'rect': pos+b[2:],
                 'ancestors': list(ancestors), 'mask': p.get('UIAutoresizingMask', 0)}
        if 'UIImage' in p:
            image = objects[p['UIImage']['ref']]['properties']
            entry['image'] = 'assets/'+objects[image['UIResourceName']['ref']]['properties']['NS.bytes']
        entries.append(entry)
        if 'UISubviews' in p:
            children = objects[p['UISubviews']['ref']]['properties'].get('UINibEncoderEmptyKey', [])
            for child in children if isinstance(children, list) else [children]:
                walk(child['ref'], pos, ancestors+(index,))

    walk(403)
    return {'source_sha256': nib['sha256'], 'source_canvas': [768, 1024], 'entries': entries}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def cgbi_image(data):
    """Apple PNG: raw DEFLATE, PNG row filters, BGRA, premultiplied alpha."""
    at, compressed = 8, bytearray()
    while at < len(data):
        length = struct.unpack_from(">I", data, at)[0]
        kind, chunk = data[at+4:at+8], data[at+8:at+8+length]
        if kind == b"IHDR":
            w, h, bits, color, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            compressed.extend(chunk)
        at += length + 12
    assert bits == 8 and color in (2, 6) and interlace == 0
    channels = 4 if color == 6 else 3
    raw = zlib.decompress(compressed, -15)
    stride = w * channels
    assert len(raw) == (stride + 1) * h
    previous = bytearray(stride)
    pixels = bytearray()
    for y in range(h):
        start = y * (stride + 1)
        filt, row = raw[start], bytearray(raw[start+1:start+1+stride])
        for x in range(stride):
            a = row[x-channels] if x >= channels else 0
            b = previous[x]
            c = previous[x-channels] if x >= channels else 0
            if filt == 1:
                row[x] = (row[x] + a) & 255
            elif filt == 2:
                row[x] = (row[x] + b) & 255
            elif filt == 3:
                row[x] = (row[x] + (a+b)//2) & 255
            elif filt == 4:
                p = a+b-c
                distances = [abs(p-a), abs(p-b), abs(p-c)]
                row[x] = (row[x] + [a, b, c][distances.index(min(distances))]) & 255
            else:
                assert filt == 0, filt
        previous = row
        for x in range(0, stride, channels):
            b, g, r = row[x:x+3]
            alpha = row[x+3] if channels == 4 else 255
            if 0 < alpha < 255:
                r, g, b = (min(255, (v*255+alpha//2)//alpha) for v in (r, g, b))
            pixels.extend((r, g, b, alpha))
    return Image.frombytes("RGBA", (w, h), bytes(pixels))


def decode(path):
    data = path.read_bytes()
    if data[:8] == b"\x89PNG\r\n\x1a\n" and b"CgBI" in data[:40]:
        return cgbi_image(data)
    return Image.open(io.BytesIO(data)).convert("RGBA")


def parse_xml(path, repairs):
    text = path.read_text(encoding="utf-8-sig")
    original = text
    # Comments before the XML declaration are harmless authored preamble.
    text = re.sub(r"<\?xml[^>]*\?>", "", text)
    if path.name in ("lobby_map.xml", "map_100.xml"):
        text = text.replace("/n<xml>", "\n<xml>", 1)
    if path.name == "tower16_3.xml" and text.startswith("scrum"):
        text = text[len("scrum"):]
    if path.name == "map_1004.xml":
        text = text.replace("<y>0</y>\n</objects>", "<y>0</y>\n</obj>\n</objects>", 1)
    root = ET.fromstring(text)
    if text != re.sub(r"<\?xml[^>]*\?>", "", original):
        repairs.append({"source": str(path.relative_to(ROOT)), "source_sha256": sha(path),
                        "rule": path.name, "derived_xml_sha256": hashlib.sha256(text.encode()).hexdigest()})
    return root


def scalar(node, key, default=0):
    value = node.findtext(key)
    if value is None:
        return default
    try:
        f = float(value)
        return int(f) if f.is_integer() else f
    except ValueError:
        return value.strip()


def flat(node):
    return {c.tag: scalar(node, c.tag, "") for c in node if len(c) == 0}


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)
    candidates = defaultdict(list)
    allowed = {".png", ".jpg", ".jpeg", ".xml", ".caf", ".mp3", ".ttf", ".otf"}
    roots = [IPA] + sorted((ORIGINAL / "game-files/downloaded-packs").iterdir(), key=lambda p: int(p.name))
    for root in roots:
        for path in sorted(root.rglob("*")):
            if path.suffix.lower() in allowed and not any(x.startswith(".") or x == "__MACOSX" for x in path.relative_to(root).parts):
                candidates[path.relative_to(root).as_posix()].append(path)
    for folder, prefix in [("cosmetic", "cosmetics"), ("cosmetic-preview", "cosmetics/previews")]:
        for path in sorted((ORIGINAL / "downloaded-cosmetics" / folder).glob("*.png")):
            candidates[prefix + "/" + path.name].append(path)

    selected = {key: paths[0] for key, paths in sorted(candidates.items())}
    manifest, conflicts, repairs, missing, format_collisions = [], [], [], [], []
    images = {}
    for key, source in selected.items():
        hashes = [sha(x) for x in candidates[key]]
        record = {"logical_path": key, "selected": str(source.relative_to(ROOT)), "sha256": hashes[0],
                  "candidates": [{"path": str(p.relative_to(ROOT)), "sha256": h} for p, h in zip(candidates[key], hashes)]}
        if len(set(hashes)) > 1:
            conflicts.append({"path": key, "resolution": "bundled-1.14-first-then-lowest-pack-id", "candidates": record["candidates"]})
        dest = OUT / key
        dest.parent.mkdir(parents=True, exist_ok=True)
        ext = source.suffix.lower()
        if ext in (".png", ".jpg", ".jpeg"):
            dest = dest.with_suffix(".png")
            stem = key.rsplit(".", 1)[0]
            if ext != ".png" and stem+".png" in selected:
                # Explicit reconstruction policy for extensionless references: PNG first.
                # Preserve the separately authored JPEG rather than overwriting either image.
                dest = (OUT / key).with_suffix(ext+".png")
                format_collisions.append({"stem": stem, "default": stem+".png", "alternate": dest.relative_to(GAME).as_posix(), "resolution": "explicit-PNG-default-with-separate-JPEG-output"})
            unchanged = cache_valid(key, record["sha256"], dest)
            img = Image.open(dest) if unchanged else decode(source)
            images[key] = (dest.relative_to(GAME).as_posix(), img.size)
            if ext == ".png" or stem not in images:
                images[stem] = (dest.relative_to(GAME).as_posix(), img.size)
            if not unchanged:
                img.save(dest, compress_level=6)
            record["conversion"] = "CgBI-BGRA-unpremultiply" if b"CgBI" in source.read_bytes()[:40] else "RGBA-PNG"
            record["size"] = list(img.size)
        elif ext == ".caf":
            dest = dest.with_suffix(".wav")
            if not cache_valid(key, record["sha256"], dest):
                # Apple's decoder also supports CAFs whose descriptors FFmpeg rejects.
                subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(source), str(dest)], check=True)
            record["conversion"] = "Apple-afconvert-PCM-s16le-WAV"
        elif ext == ".xml":
            parse_xml(source, repairs)
            # XML stays in the manifest; runtime consumes validated structured data.
            dest = None
        else:
            if not cache_valid(key, record["sha256"], dest):
                shutil.copyfile(source, dest)
        if dest:
            record.update(runtime=dest.relative_to(GAME).as_posix(), runtime_sha256=sha(dest))
        manifest.append(record)

    def image_ref(parent, name):
        logical = posixpath.normpath(str(parent) + "/" + name)
        if logical in images:
            return images[logical][0]
        logical = logical.removesuffix(".png").removesuffix(".jpg")
        if logical in images:
            return images[logical][0]
        if name in images:
            return images[name][0]
        missing.append({"parent": str(parent), "filename": name})
        return ""

    animations = {}
    for key, source in selected.items():
        if not key.endswith(".xml"):
            continue
        xml = parse_xml(source, [])
        parent = posixpath.dirname(key)
        resources = {}
        for r in xml.findall("resources/res"):
            item = flat(r)
            item["texture"] = image_ref(parent, str(item.get("filename", "")))
            item["variations"] = {v.findtext("name"): image_ref(parent, v.findtext("filename", "")) for v in r.findall("variations/v")}
            resources[str(item.get("id", 1))] = item
        states = {}
        for anim in xml.findall("animations/anim"):
            state = flat(anim)
            state["added_frames"] = [flat(f) for f in anim.findall("add_frames/f")]
            states[str(state.get("name", "Idle"))] = state
        extras = xml.find("extra")
        textures = {t.findtext("name", ""): {**flat(t), "texture": image_ref(parent, t.findtext("filename", ""))} for t in xml.findall("extra/textures/t")}
        for t in xml.findall("extra/textures/t"):
            textures[t.findtext("name", "")]["variations"] = {v.findtext("name"): image_ref(parent, v.findtext("filename", "")) for v in t.findall("variations/v")}
        params = {}
        for p in xml.findall("extra/params/p"):
            name, kind, value = p.findtext("name"), int(p.findtext("type", "4")), p.find("value")
            if value is None:
                continue
            params[name] = [v.findtext("str", "") for v in value.findall("v")] if kind == 5 else [float(v) for v in (value.text or "").split()] if kind == 3 else scalar(p, "value")
        if states:
            animations[key[:-4]] = {"resources": resources, "states": states, "extra": flat(extras) if extras is not None else {}, "params": params, "textures": textures}

    # A separate audit includes particle aliases and every XML filename edge.
    logical_stems = {key.rsplit(".", 1)[0] for key in selected}
    basename_stems = {key.rsplit("/", 1)[-1] for key in logical_stems}
    aliases = set()
    for key, source in selected.items():
        if key.endswith(".xml"):
            aliases.update((n.text or "").strip() for n in parse_xml(source, []).iter("name"))
    filename_edges, unresolved_edges = [], []
    for key, source in selected.items():
        if not key.endswith(".xml"):
            continue
        for node in parse_xml(source, []).iter("filename"):
            name = (node.text or "").strip()
            stem = re.sub(r"\.(png|jpg|jpeg|xml|caf|mp3)$", "", name)
            target = posixpath.normpath(posixpath.dirname(key) + "/" + stem)
            resolved = target in logical_stems or stem in logical_stems or stem in basename_stems or stem in aliases
            edge = {"source": key, "filename": name, "resolved": resolved}
            filename_edges.append(edge)
            if not resolved:
                unresolved_edges.append(edge)

    maps = {}
    for key, source in selected.items():
        if not re.fullmatch(r"maps/(map_\d+|lobby_map)\.xml", key):
            continue
        m = parse_xml(source, []).find("map")
        entry = flat(m)
        entry["cells"] = [flat(c) for c in m.findall("hex_grid/c")]
        entry["effects"] = [flat(e) for e in m.findall("effects/e")]
        layers = []
        tile_sets = {}
        for r in m.findall("tile_res/res"):
            name = r.findtext("filename", "")
            metadata = selected.get("maps/" + name + ".xml")
            if metadata:
                tiles = parse_xml(metadata, []).find("tiles")
                tile_sets[r.findtext("id")] = {str(scalar(t, "id")): flat(t) for t in tiles} if tiles is not None else {}
            else:
                missing.append({"map": key, "tile_metadata": name})
            tile_sets.setdefault(r.findtext("id"), {})["texture"] = image_ref("maps", name)
        for obj in m.findall("objects/obj"):
            o = flat(obj)
            tiles = tile_sets.get(str(o.get("atlas_id")), {})
            tile = tiles.get(str(o.get("tile_id")), {})
            if not tile:
                missing.append({"map": key, "object": o})
            layers.append({**o, "tile": tile, "texture": tiles.get("texture", "")})
        layers.sort(key=lambda o: (0 if o["tile"].get("map_bgr") or o["tile"].get("no_depth") else 1, o.get("y", 0), o.get("obj_id", 0)))
        entry["layers"] = layers
        foreground = [o for o in layers if o["tile"].get("object") and not o["tile"].get("map_bgr") and not o["tile"].get("no_depth")]
        entry["foreground"] = foreground
        w, h = int(entry.get("width_pixels", 1024)), int(entry.get("height_pixels", 738))
        canvas = Image.new("RGBA", (w, h), (11, 79, 105, 255))
        for o in layers:
            if o in foreground:
                continue
            if not o["texture"]:
                continue
            im = Image.open(GAME / o["texture"]).convert("RGBA")
            t = o["tile"]
            sx, sy, tw, th = (int(t.get(k, default)) for k, default in [("sx", 0), ("sy", 0), ("w", im.width), ("h", im.height)])
            crop = im.crop((sx, sy, sx+tw, sy+th))
            canvas.alpha_composite(crop, (int(o.get("x", 0)+t.get("offset_x", 0)), int(o.get("y", 0)+t.get("offset_y", 0))))
        out = OUT / "rendered" / (source.stem + ".png")
        out.parent.mkdir(exist_ok=True)
        canvas.save(out)
        entry["background"] = out.relative_to(GAME).as_posix()
        maps[source.stem.replace("map_", "")] = entry

    user = json.loads((ORIGINAL / "analysis/offline_data.json").read_text())["userData"]
    keep = ["tower_towers", "tower_creeps", "tower_upgrades", "tower_magic", "tower_medals", "tower_locations", "tower_dress", "tower_rewards", "tower_upgrade_costs", "tower_sell_return", "tower_max_wave_length", "tower_targeting_delay", "tower_targeting_duration", "shopList", "configs", "offlineConfigs", "tower_pu_exchange"]
    catalog = {k: user[k] for k in keep}
    catalog["resource_params"] = {key: value["params"] for key, value in animations.items()}
    sounds = parse_xml(IPA / "sounds/sounds.xml", []).find("sounds")
    catalog["soundbank"] = {s.findtext("filename"): flat(s) for s in sounds}
    for c in catalog["offlineConfigs"]:
        for field in ("sources", "bases", "waves", "settings"):
            c[field + "_raw"] = c[field]
            c[field] = json.loads(c[field]) if c[field] else {} if field == "settings" else []
        for wave in c["waves"]:
            wave["indicator"] = {"boss": 0, "fast": 1, "chain": 2, "slow&strong": 3}.get(wave["type"], 4)
            wave["creep_ids"] = [int(x) if x not in ("-", "") else 0 for x in wave["creeps"].split(",")]
            wave["source_ids"] = [int(x) if x else 0 for x in wave["sources"].split(",")]
    campaign_issues = []
    for c in catalog["offlineConfigs"]:
        if not c["waves"]:
            continue
        m = maps.get(c["map"])
        if not m:
            campaign_issues.append({"config": c["configid"], "missing_map": c["map"]})
            continue
        assert len(m["cells"]) == m["hex_width"]*m["hex_height"], c["map"]
        for wi, wave in enumerate(c["waves"]):
            if len(wave["creep_ids"]) != len(wave["source_ids"]):
                campaign_issues.append({"config": c["configid"], "wave": wi+1, "creep_slots": len(wave["creep_ids"]), "source_slots": len(wave["source_ids"]), "status": "code-traced-extra-source-entry-unused", "evidence": "CRoom::ProcessWaves 0xd3f78-0xd3f96"})
            for enemy in wave["creep_ids"]:
                if enemy != 0 and not user["tower_creeps"][enemy].get("filename"):
                    campaign_issues.append({"config": c["configid"], "wave": wi+1, "undefined_enemy": enemy, "status": "code-traced-null-resource-slot-skipped", "evidence": "CCreepManager::AddCreep 0xfb8a8-0xfb8ac"})
            for si in wave["source_ids"]:
                if si >= len(c["sources"]):
                    campaign_issues.append({"config": c["configid"], "wave": wi+1, "source_index": si, "source_count": len(c["sources"]), "status": "code-traced-absent-source-slot-skipped", "evidence": "CRoom::ProcessWaves 0xd3fa4-0xd3fac"})
    save_json(DATA / "catalog.json", catalog)
    save_json(DATA / "menu_layout.json", menu_layout())
    save_json(DATA / "maps.json", maps)
    save_json(DATA / "animations.json", animations)
    save_json(DATA / "import_manifest.json", {"schema": 1, "baseline": "1.14", "assets": manifest, "conflicts": conflicts, "format_collisions": format_collisions, "repairs": repairs, "missing_references": missing, "filename_edges": filename_edges, "unresolved_filename_edges": unresolved_edges, "campaign_issues": campaign_issues})
    save_json(ROOT / "docs/content-audit.json", {"schema": 1, "assets": len(manifest), "maps": len(maps), "animation_sets": len(animations), "conflicts": conflicts, "format_collisions": format_collisions, "repairs": repairs, "missing_references": missing, "filename_edge_count": len(filename_edges), "unresolved_filename_edges": unresolved_edges, "campaign_issues": campaign_issues, "catalog_sha256": sha(DATA / "catalog.json"), "maps_sha256": sha(DATA / "maps.json"), "animations_sha256": sha(DATA / "animations.json")})
    print(json.dumps({"assets": len(manifest), "maps": len(maps), "animations": len(animations), "conflicts": len(conflicts), "missing": len(missing), "campaign_issues": len(campaign_issues)}))


if __name__ == "__main__":
    old = DATA / "import_manifest.json"
    previous = {a["logical_path"]: a for a in json.loads(old.read_text())["assets"]} if old.exists() else {}
    def cache_valid(key, source_hash, dest):
        entry = previous.get(key, {})
        return dest.exists() and entry.get("sha256") == source_hash and entry.get("runtime_sha256") == sha(dest)
    run()
