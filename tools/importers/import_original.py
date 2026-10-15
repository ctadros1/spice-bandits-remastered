#!/usr/bin/env python3
"""Deterministically derive Godot content. Never writes beneath original/."""
import argparse
import hashlib
import io
import json
import os
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
        if 'UITag' in p: entry['tag'] = p['UITag']
        if 'UIAlpha' in p: entry['alpha'] = p['UIAlpha']
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


def tutorial_layout():
    """Read TutorialView's authored portrait, stretch strip, and hint label."""
    nib = decode_nib(IPA / 'TutorialView.nib')
    objects = nib['objects']
    entries = []
    for index in (27, 17, 13, 22):
        p = objects[index]['properties']
        b, c = p['UIBounds'], p['UICenter']
        entry = {'id': index, 'rect': [c[0]-b[2]/2, c[1]-b[3]/2]+b[2:],
                 'mask': p['UIAutoresizingMask']}
        if 'UIImage' in p:
            image = objects[p['UIImage']['ref']]['properties']
            entry['image'] = 'assets/'+objects[image['UIResourceName']['ref']]['properties']['NS.bytes']
        if 'UIFont' in p:
            entry['font_size'] = objects[p['UIFont']['ref']]['properties']['UIFontPointSize']
        entries.append(entry)
    hint=objects[36]['properties']
    bounds,center=hint['UIBounds'],hint['UICenter']
    return {'source_sha256': nib['sha256'], 'source_canvas': [768, 260], 'entries': entries,
            'hint_rect':[center[0]-bounds[2]/2,center[1]-bounds[3]/2]+bounds[2:]}


def tutorial_gl_layout():
    """Derived original ARM declarations, separate from the portrait NIB."""
    fixture = ROOT / 'tests/fixtures/native-tutorial-layout-reference.json'
    reference = json.loads(fixture.read_text())
    assert reference['original_unchanged']
    assert reference['original_sha256'] == hashlib.sha256((IPA / 'Tower').read_bytes()).hexdigest()
    pages = {str(c['page']): [dict(id=key, **value) for key, value in sorted(c['objects'].items())]
             for c in reference['cases'] if c['device'] == 2}
    assert set(pages) == set(map(str, range(18)))
    return {'source_executable_sha256': reference['original_sha256'],
            'reference_fixture_sha256': hashlib.sha256(fixture.read_bytes()).hexdigest(),
            'method': reference['method'], 'pages': pages}


def interface_layout(filename, root_id, detached_outlets=()):
    """Retain original UIKit art, labels, buttons and hierarchy for UI ports."""
    nib = decode_nib(IPA / filename)
    objects = nib['objects']
    outlets = {}
    for obj in objects:
        if obj['class'] == 'UIRuntimeOutletConnection':
            p = obj['properties']
            outlets[p['UIDestination']['ref']] = objects[p['UILabel']['ref']]['properties']['NS.bytes']

    def props(ref):
        return objects[ref['ref']]['properties'] if isinstance(ref, dict) and 'ref' in ref else {}

    def image_name(ref):
        image = props(ref)
        value = props(image.get('UIResourceName')).get('NS.bytes', '')
        return 'assets/'+str(Path(value).with_suffix('.png')) if value else ''

    def color(ref):
        p = props(ref)
        white = float(p.get('UIWhite', 1))
        return [float(p.get(k, white)) for k in ('UIRed', 'UIGreen', 'UIBlue')]+[float(p.get('UIAlpha', 1))]

    entries = []
    visited = set()

    def walk(index, offset=(0, 0), ancestors=()):
        if index in visited: return
        visited.add(index)
        obj = objects[index]
        p = obj['properties']
        b, c = p.get('UIBounds', [0, 0, 0, 0]), p.get('UICenter', [0, 0])
        pos = [offset[0]+c[0]-b[2]/2, offset[1]+c[1]-b[3]/2]
        entry = {'id': index, 'class': obj['class'], 'outlet': outlets.get(index, ''), 'rect': pos+b[2:],
                 'ancestors': list(ancestors), 'mask': p.get('UIAutoresizingMask', 0), 'hidden': bool(p.get('UIHidden', False))}
        if 'UIContentMode' in p: entry['content_mode'] = p['UIContentMode']
        if 'UITag' in p: entry['tag'] = p['UITag']
        if 'UIImage' in p: entry['image'] = image_name(p['UIImage'])
        if 'UIText' in p:
            f = props(p.get('UIFont'))
            entry.update(text=props(p['UIText']).get('NS.bytes', ''), font_size=float(f.get('UIFontPointSize', 17)),
                         bold=bool(int(f.get('UIFontTraits', 0)) & 2), alignment=int(p.get('UITextAlignment', 0)), color=color(p.get('UITextColor')))
            entry['line_count'] = int(p.get('UINumberOfLines', 1))
        if 'UIButtonStatefulContent' in p:
            f=props(p.get('UIFont'))
            entry['button_font_size']=float(f.get('UIFontPointSize',17))
            entry['button_bold']=bool(int(f.get('UIFontTraits',0)) & 2)
            state = props(p['UIButtonStatefulContent']).get('UINibEncoderEmptyKey', [])
            entry['button_images'] = {}
            entry['button_titles'] = {}
            for i in range(0, len(state), 2):
                key = str(props(state[i]).get('NS.intval', 0))
                content = props(state[i+1])
                entry['button_images'][key] = image_name(content.get('UIImage', content.get('UIBackgroundImage')))
                entry['button_titles'][key] = props(content.get('UITitle')).get('NS.bytes', '')
        entries.append(entry)
        children = props(p.get('UISubviews')).get('UINibEncoderEmptyKey', [])
        for child in children if isinstance(children, list) else [children]: walk(child['ref'], pos, ancestors+(index,))

    walk(root_id)
    for index, outlet in outlets.items():
        if outlet in detached_outlets and index not in visited: walk(index)
    return {'source_sha256': nib['sha256'], 'source_canvas': objects[root_id]['properties']['UIBounds'][2:], 'root': root_id, 'entries': entries}


def interface_tutorials():
    """Exact English keys from TutorialView::updateViewWithType0x65b94."""
    executable = IPA / 'Tower'
    prefixes = {2: 'Welcome to Earth cadet!', 3: 'Get ready for your first real mission.',
                5: 'Congratulations on your first promotion', 6: 'Congratulations again, you are doing really well!', 7: 'This is the place where you buy new weapons.',
                8: 'Look at those shiny missiles.', 9: "Great job. Now let's get back to the map",
                21: 'Wish your towers were dealing more damage', 22: 'This is your career screen.',
                23: "You aren't going to fight naked, are you?",24:'Ahhh, spice!'}
    strings = executable.read_bytes().split(b'\0')
    texts = {}
    for kind, prefix in prefixes.items():
        matches = [s.decode('utf-8') for s in strings if s.startswith(prefix.encode())]
        if len(matches) != 1: raise ValueError(('Tutorial text must resolve uniquely', kind, matches))
        texts[str(kind)] = matches[0]
    matches = [s.decode('utf-8') for s in strings if s.startswith(b'Tap to use or buy magic for spice.')]
    if len(matches) != 1: raise ValueError(('Magic panel title must resolve uniquely', matches))
    magic_title = matches[0]
    spicery_texts = {}
    for key, prefix in {'header':'Here you can get different doses of our favorite stuff!',
                        'social':'Socialize,', 'ads':'Check out an ad from our',
                        'gift':'Start gifting fun!'}.items():
        matches = sorted(set(s.decode('utf-8') for s in strings if s.startswith(prefix.encode())))
        if len(matches) != 1: raise ValueError(('Spice Shop text must resolve uniquely',key,matches))
        spicery_texts[key]=matches[0]
    mode_texts = {}
    for key, prefix in {'normal': 'Defend the base alone', 'training': 'Learn to play the game',
                        'sudden_death': "Don't let anyone near the base", 'air_attack': 'Mostly air enemy units',
                        'locked': 'Still locked', 'offline': 'You must be online for multiplayer', 'players': 'players'}.items():
        matches = sorted(set(s.decode('utf-8') for s in strings if s == prefix.encode()))
        if len(matches) != 1: raise ValueError(('Mode text must resolve uniquely', key, matches))
        mode_texts[key] = matches[0]
    upgrades_texts = {}
    for key, prefix in {'header': "Use upgrade points to enhance your pirate's skills",
                        'exchange': 'get %d upgrade points for %dsp'}.items():
        matches = [s.decode('utf-8') for s in strings if s.startswith(prefix.encode())]
        if len(matches) != 1: raise ValueError(('Upgrade text must resolve uniquely', key, matches))
        upgrades_texts[key] = matches[0]
    return {'executable_sha256': sha(executable), 'function': 'TutorialView::updateViewWithType0x65b94',
            'texts': texts, 'magic_panel_title': magic_title, 'magic_title_function': 'CRoom::LoadTexts0xc6504',
            'spicery_texts':spicery_texts,'spicery_text_function':'SpiceShopViewController::viewDidLoad0x261f0',
            'mode_texts': mode_texts, 'mode_text_function': 'CChooseConfigPanel::CChooseConfigPanel0x87f68',
            'upgrades_texts': upgrades_texts, 'upgrades_text_function': 'UpgradesViewController::updateUserInfo0x31fa4/viewDidLoad0x31230'}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def convert_movie(source, destination):
    """Derived Theora/Vorbis for Godot, retaining authored dimensions/rate/audio."""
    converter = os.environ.get('SPICE_VIDEO_CONVERTER', str(ROOT / 'work/toolchain/ffmpeg-build/ffmpeg-8.1.3/ffmpeg'))
    version = subprocess.check_output([converter, '-version'], text=True).splitlines()[0]
    if not version.startswith('ffmpeg version 8.1.3 '):
        raise RuntimeError('Publisher video conversion requires pinned FFmpeg 8.1.3; see docs/BUILD.md')
    subprocess.run([converter, '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
                    '-fflags', '+bitexact', '-i', str(source), '-map', '0:v:0', '-map', '0:a:0',
                    '-map_metadata', '-1', '-c:v', 'libtheora', '-q:v', '10', '-pix_fmt', 'yuv420p',
                    '-flags:v', '+bitexact', '-c:a', 'libvorbis', '-q:a', '8', '-flags:a', '+bitexact',
                    '-fflags', '+bitexact', '-serial_offset', '0', str(destination)], check=True)


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def cgbi_image(data, unpremultiply=True):
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
            if unpremultiply and 0 < alpha < 255:
                r, g, b = (min(255, (v*255+alpha//2)//alpha) for v in (r, g, b))
            pixels.extend((r, g, b, alpha))
    return Image.frombytes("RGBA", (w, h), bytes(pixels))


def decode(path):
    data = path.read_bytes()
    if data[:8] == b"\x89PNG\r\n\x1a\n" and b"CgBI" in data[:40]:
        return cgbi_image(data)
    return Image.open(io.BytesIO(data)).convert("RGBA")


def native_grayscale(image, percentage=1.0):
    """ConvertRGBA2Gray0x12542c on premultiplied RGBA; return straight RGBA."""
    f32 = lambda value: struct.unpack('<f', struct.pack('<f', value))[0]
    weights = [f32(n) for n in (0.3, 0.59, 0.11)]
    pixels = bytearray()
    for r, g, b, alpha in image.getdata():
        value = int(f32(f32(f32(r*weights[0])+f32(g*weights[1]))+f32(b*weights[2])))
        channels = [int(f32(f32(channel*f32(1.0-percentage))+f32(value*percentage))) for channel in (r,g,b)] if percentage != 1.0 else [value]*3
        if 0 < alpha < 255: channels = [min(255, (channel*255+alpha//2)//alpha) for channel in channels]
        pixels.extend((*channels,alpha))
    return Image.frombytes('RGBA',image.size,bytes(pixels))


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


def typed_params(node):
    """CResourceManager::LoadParams: retain nested shooting points and vectors."""
    result = {}
    for p in node.findall('p'):
        name, kind, value = p.findtext('name'), int(p.findtext('type', '4')), p.find('value')
        if kind == 7:
            child = p.find('params')
            result[name] = typed_params(child) if child is not None else {}
        elif value is not None:
            if kind == 5:
                result[name] = [v.findtext('str', '') for v in value.findall('v')]
            elif kind == 6:
                result[name] = [[float(n) for n in (v.text or '').split()] for v in value.findall('vec')]
            elif kind == 3:
                result[name] = [float(n) for n in (value.text or '').split()]
            else:
                result[name] = scalar(p, 'value')
    return result


def resolve_frames(anim, state, resources):
    """Expand authored stacks in native order, including reverse/mirrored halves.

    LoadAnimations 0x11a530 appends stacks before individual added frames.
    AddFrameStack 0x10e8d0 wraps before a frame whose right edge reaches
    the texture width. Stack offsets inherit the animation; explicit added
    frames add their own offsets to the animation offsets in AddFrame.
    AddFrameStack offsets are already absolute relative to the animator.
    """
    result = []
    resource_id = str(int(state.get('res_id', 1)))
    resource = resources[resource_id]
    fw, fh = int(resource['frame_width']), int(resource['frame_height'])
    width = int(resource['texture_width'])
    x = int(state.get('start_x', (int(state.get('column', 1))-1)*fw))
    y = int(state.get('start_y', (int(state.get('raw', 1))-1)*fh))
    for _ in range(int(state.get('frames', 0))):
        if x+fw > width: x, y = 0, y+fh
        result.append({'res_id': int(resource_id), 'x': x, 'y': y,
                       'offset_x': state.get('offset_x', 0), 'offset_y': state.get('offset_y', 0),
                       'fliph': state.get('fliph', 0)})
        x += fw
    for stack_node in anim.findall('add_frame_stacks/frame_stack'):
        stack = flat(stack_node)
        rid = str(int(stack.get('res_id', resource_id)))
        r = resources[rid]
        sw, sh, width = int(r['frame_width']), int(r['frame_height']), int(r['texture_width'])
        x, y = int(stack.get('x', stack.get('start_x', 0))), int(stack.get('y', stack.get('start_y', 0)))
        frames = []
        for _ in range(int(stack.get('frames', 0))):
            if x+sw >= width: x, y = 0, y+sh
            frames.append({'res_id': int(rid), 'x': x, 'y': y, 'fliph': stack.get('fliph', 0),
                           'offset_x': stack.get('offset_x', state.get('offset_x', 0)),
                           'offset_y': stack.get('offset_y', state.get('offset_y', 0))})
            x += sw
        result.extend(reversed(frames) if stack.get('reverse_frames', 0) else frames)
    result.extend({**flat(f), "native_added": 1} for f in anim.findall('add_frames/f'))
    return result


def run():
    OUT.mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)
    candidates = defaultdict(list)
    allowed = {".png", ".jpg", ".jpeg", ".xml", ".caf", ".mp3", ".ttf", ".otf", ".mov"}
    roots = [IPA] + sorted((p for p in (ORIGINAL / "game-files/downloaded-packs").iterdir()
                           if p.is_dir() and p.name.isdecimal()), key=lambda p: int(p.name))
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
        elif ext == ".mov":
            dest = dest.with_suffix('.ogv')
            if not cache_valid(key, record['sha256'], dest):
                convert_movie(source, dest)
            record['conversion'] = 'FFmpeg-8.1.3-Theora-q10-Vorbis-q8-bitexact'
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
    static_resources = {}
    particles = {'systems': {}, 'bindings': {}}
    runtime_sizes = {path: size for path, size in images.values()}
    gray_images = {}
    screen_textures = {}
    def screen_texture(texture):
        if not texture or texture in screen_textures: return
        source = next(Path(a["selected"]) for a in manifest if a.get("runtime") == texture)
        data = source.read_bytes()
        if b"CgBI" in data[:40]: image = cgbi_image(data, unpremultiply=False)
        else:
            straight = decode(source)
            image = Image.frombytes("RGBA", straight.size, bytes(v for pixel in straight.getdata() for v in tuple((n*pixel[3]+127)//255 for n in pixel[:3])+(pixel[3],)))
        # Keep exact source premultiplied RGB. LCD requires opaque storage;
        # the per-draw coefficient is carried separately in modulation alpha.
        image.putalpha(255)
        derived = OUT / "derived/screen" / Path(texture).relative_to("assets")
        derived.parent.mkdir(parents=True,exist_ok=True)
        image.save(derived,compress_level=6)
        screen_textures[texture] = derived.relative_to(GAME).as_posix()
    def gray_texture(texture, percentage=1.0):
        key=(texture,percentage)
        if key not in gray_images:
            source = next(Path(a['selected']) for a in manifest if a.get('runtime') == texture)
            data = source.read_bytes()
            if b'CgBI' in data[:40]: image = cgbi_image(data, unpremultiply=False)
            else:
                image = decode(source)
                image = Image.frombytes('RGBA',image.size,bytes(v for pixel in image.getdata() for v in tuple((n*pixel[3]+127)//255 for n in pixel[:3])+pixel[3:]))
            derived = OUT / ('derived/grayscale' if percentage==1.0 else 'derived/gray50') / Path(texture).relative_to('assets')
            derived.parent.mkdir(parents=True,exist_ok=True)
            native_grayscale(image,percentage).save(derived,compress_level=6)
            gray_images[key] = derived.relative_to(GAME).as_posix()
        return gray_images[key]
    for icon in ['norm','sd','air','cmp','coo','mp']:
        gray_texture('assets/lobby/icons/'+icon+'_1.png',.5)
    for key, source in selected.items():
        if not key.endswith(".xml"):
            continue
        xml = parse_xml(source, [])
        parent = posixpath.dirname(key)
        for node in xml.findall('particles/p'):
            item = flat(node)
            for field in ('color', 'velocity', 'gravity', 'wind'):
                if field in item: item[field] = [float(n) for n in str(item[field]).split()]
            item['texture'] = image_ref(parent, str(item.get('filename', '')))
            item['variations'] = {v.findtext('name'): image_ref(parent, v.findtext('filename', '')) for v in node.findall('variations/v')}
            item['texture_list'] = [flat(t) for t in node.findall('texture_list/t')]
            item['source'] = key
            item['source_sha256'] = sha(source)
            particles['systems'][str(item['name'])] = item
        bindings = {p.findtext('name'): flat(p) for p in xml.findall('extra/particles/p')}
        if bindings: particles['bindings'][key[:-4]] = bindings
        resources = {}
        for r in xml.findall("resources/res"):
            item = flat(r)
            item["texture"] = image_ref(parent, str(item.get("filename", "")))
            item['texture_width'], item['texture_height'] = runtime_sizes.get(item['texture'], (0, 0))
            item["variations"] = {v.findtext("name"): image_ref(parent, v.findtext("filename", "")) for v in r.findall("variations/v")}
            if key.startswith("creeps/"):
                for texture in [item["texture"], *item["variations"].values()]: screen_texture(texture)
            resources[str(item.get("id", 1))] = item
        states = {}
        for anim in xml.findall("animations/anim"):
            state = flat(anim)
            state["added_frames"] = [flat(f) for f in anim.findall("add_frames/f")]
            state['frame_stacks'] = [flat(f) for f in anim.findall('add_frame_stacks/frame_stack')]
            state['resolved_frames'] = resolve_frames(anim, state, resources)
            states[str(state.get("name", "Idle"))] = state
        extras = xml.find("extra")
        # CResourceManager::LoadTextures0x118a74 iterates every child, including
        # both the newer <t> and preserved <texture> spelling.
        texture_nodes = xml.findall("extra/textures/*")
        textures = {t.findtext("name", ""): {**flat(t), "texture": image_ref(parent, t.findtext("filename", ""))} for t in texture_nodes}
        for t in texture_nodes:
            textures[t.findtext("name", "")]["variations"] = {v.findtext("name"): image_ref(parent, v.findtext("filename", "")) for v in t.findall("variations/v")}
        for item in textures.values():
            if item.get('tex_params') == 'gray' and item['texture']:
                item['source_texture'] = item['texture']
                item['texture'] = gray_texture(item['texture'])
        params_node = xml.find('extra/params')
        params = typed_params(params_node) if params_node is not None else {}
        if states:
            animations[key[:-4]] = {"resources": resources, "states": states, "extra": flat(extras) if extras is not None else {}, "params": params, "textures": textures}
        elif textures:
            # Original world/UI texture sets need no animation states. Preserve
            # them separately rather than silently dropping their atlas metadata.
            for t in texture_nodes:
                node = t.find('params')
                textures[t.findtext('name', '')]['params'] = typed_params(node) if node is not None else {}
            static_resources[key[:-4]] = {"resources": resources, "params": params, "textures": textures}

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
        entry["animated_objects"] = []
        for obj in m.findall("animated_objects/obj"):
            definition = flat(obj)
            name = obj.findtext("texture/filename", "")
            definition["texture"] = image_ref("maps", name)
            definition["frames"] = [{"pos": [float(v) for v in f.findtext("pos", "0 0").split()],
                                     "angle": float(f.findtext("angle", "0"))} for f in obj.findall("frames/f")]
            definition["source_sha256"] = sha(source)
            entry["animated_objects"].append(definition)
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
        water = m.find("water")
        if water is not None:
            # CMap::Load0xffd90 reads the mask frame bounds from `texure`
            # too, rather than from `mask_texture`. Preserve that native quirk.
            texture_node = water.find("texure")
            def water_bounds(texture):
                size = Image.open(GAME / texture).size
                x, y = (float(texture_node.findtext(k, "0")) for k in ["x", "y"])
                fw, fh = (float(texture_node.findtext(k, "1")) for k in ["frame_width", "frame_height"])
                return [x/size[0], (x+fw)/size[0], y/size[1], (y+fh)/size[1]]
            texture = image_ref("maps", texture_node.findtext("filename"))
            mask = image_ref("maps", water.findtext("mask_texture/filename"))
            segments = [float(n) for n in water.findtext("segments", "20 20").split()]
            if int(segments[1]) % 2: segments[1] += 1
            entry["water"] = {"texture": texture, "mask": mask,
                              "water_uv": water_bounds(texture), "mask_uv": water_bounds(mask),
                              "plane": [max(w,h)]*2, "segments": segments, "offset": [0,25],
                              "speed": float(water.findtext("speed", "4000")),
                              "amplitude": float(water.findtext("amplitude", "0.18")),
                              "density": float(water.findtext("density", "8")),
                              "mask_scale": float(water.findtext("mask_scale", "1")),
                              "seed": 78, "source_sha256": sha(source)}
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
    keep = ["tower_towers", "tower_creeps", "tower_upgrades", "tower_magic", "tower_medals", "tower_locations", "tower_dress", "tower_rewards", "tower_upgrade_costs", "tower_sell_return", "tower_max_wave_length", "tower_targeting_delay", "tower_targeting_duration", "shopList", "configs", "offlineConfigs", "tower_pu_exchange", "tower_inapp"]
    catalog = {k: user[k] for k in keep}
    catalog["resource_params"] = {key: value["params"] for key, value in animations.items()}
    catalog['soundbanks'] = {}
    for group, filename in [('game', 'sounds.xml'), ('lobby', 'loby_sounds.xml')]:
        bank = parse_xml(IPA / ('sounds/'+filename), [])
        catalog['soundbanks'][group] = {
            'default_volume': float(bank.findtext('default_volume')),
            'max_volume': float(bank.findtext('max_volume')),
            'cues': {s.findtext('filename'): flat(s) for s in bank.find('sounds')},
            'source_sha256': sha(IPA / ('sounds/'+filename))}
    catalog['soundbank'] = catalog['soundbanks']['game']['cues']
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
    save_json(DATA / "tutorial_layout.json", tutorial_layout())
    save_json(DATA / "tutorial_gl_layout.json", tutorial_gl_layout())
    save_json(DATA / "interface_tutorials.json", interface_tutorials())
    save_json(DATA / "interface_layouts.json", {
        'lobby_top': interface_layout('EAGLViewController.nib', 15),
        'lobby_bottom': interface_layout('EAGLViewController.nib', 86),
        'career': interface_layout('CareerViewController.nib', 254, ('careerView',)),
        'upgrades': interface_layout('UpgradesViewController.nib', 44),
        'upgrade_item': interface_layout('UpgradesItemViewController.nib', 50),
        'shop': interface_layout('ShopViewController.nib', 5),
        'shop_block': interface_layout('ShopBlockView.nib', 14),
        'shop_item': interface_layout('ShopItemView.nib', 47),
        'spicery': interface_layout('SpiceShopViewController.nib',245),
        'medals': interface_layout('MedalsViewController.nib', 36),
        'dress': interface_layout('DressRoomViewController.nib', 58),
        'dress_item': interface_layout('DressView.nib', 32),
        'credits': interface_layout('CreditsViewController.nib', 18, ('creditsLabelsView',)),
    })
    save_json(DATA / "maps.json", maps)
    save_json(DATA / "screen_textures.json", screen_textures)
    save_json(DATA / "animations.json", animations)
    save_json(DATA / "particles.json", particles)
    save_json(DATA / "static_resources.json", static_resources)
    save_json(DATA / "import_manifest.json", {"schema": 1, "baseline": "1.14", "assets": manifest, "conflicts": conflicts, "format_collisions": format_collisions, "repairs": repairs, "missing_references": missing, "filename_edges": filename_edges, "unresolved_filename_edges": unresolved_edges, "campaign_issues": campaign_issues})
    save_json(ROOT / "docs/content-audit.json", {"schema": 1, "assets": len(manifest), "maps": len(maps), "animation_sets": len(animations), "resolved_animation_frames": sum(len(s['resolved_frames']) for a in animations.values() for s in a['states'].values()), "frame_stacks": sum(len(s['frame_stacks']) for a in animations.values() for s in a['states'].values()), "conflicts": conflicts, "format_collisions": format_collisions, "repairs": repairs, "missing_references": missing, "filename_edge_count": len(filename_edges), "unresolved_filename_edges": unresolved_edges, "campaign_issues": campaign_issues, "catalog_sha256": sha(DATA / "catalog.json"), "maps_sha256": sha(DATA / "maps.json"), "animations_sha256": sha(DATA / "animations.json")})
    print(json.dumps({"assets": len(manifest), "maps": len(maps), "animations": len(animations), "conflicts": len(conflicts), "missing": len(missing), "campaign_issues": len(campaign_issues)}))


if __name__ == "__main__":
    old = DATA / "import_manifest.json"
    previous = {a["logical_path"]: a for a in json.loads(old.read_text())["assets"]} if old.exists() else {}
    def cache_valid(key, source_hash, dest):
        entry = previous.get(key, {})
        return dest.exists() and entry.get("sha256") == source_hash and entry.get("runtime_sha256") == sha(dest)
    run()
