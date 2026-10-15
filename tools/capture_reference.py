#!/usr/bin/env python3
"""Capture preserved footage for visual reconstruction, without warping pixels.

One full-resolution frame per second covers every supplied clip. Denser
TouchGameplay sequences retain loading, placement, electricity and reward
transitions. Contact sheets are previews; original decoded captures remain.
"""
import hashlib
import json
import subprocess
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
VIDEOS = ROOT / 'research/videos'
DEST = ROOT / 'builds/reference/dense'
# The runtime converter is intentionally an Ogg-only build. Reference capture
# uses the installed full decoder/encoder and records its version separately.
FFMPEG = Path(shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg')
SEGMENTS = [('loading', 104, 117), ('build', 133, 160),
            ('electric', 228, 247), ('tutorial-result', 272, 291),
            ('location', 298, 319), ('desert-result', 615, 649)]


def capture(source, folder, fps, start=0, duration=None):
    folder.mkdir(parents=True, exist_ok=True)
    args = [str(FFMPEG), '-nostdin', '-hide_banner', '-loglevel', 'error',
            '-ss', str(start), '-i', str(source)]
    if duration is not None:
        args += ['-t', str(duration)]
    args += ['-vf', f'fps={fps}', '-q:v', '2', '-y', str(folder / '%05d.jpg')]
    subprocess.run(args, check=True)
    files = sorted(folder.glob('*.jpg'))
    entries = [{'file': str(p.relative_to(DEST)),
                'time_seconds': round(start+(i+.5)/fps, 6),
                'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
               for i, p in enumerate(files)]
    for batch in range(0, len(files), 60):
        sheet = Image.new('RGB', (1200, 10*155), '#10151b')
        ink = ImageDraw.Draw(sheet)
        for index, p in enumerate(files[batch:batch+60]):
            im = Image.open(p).convert('RGB')
            im.thumbnail((196, 130))
            x, y = (index % 6)*200, (index//6)*155
            sheet.paste(im, (x+(196-im.width)//2, y))
            ink.text((x+3, y+132), f'{start+(batch+index+.5)/fps:.3f}s', fill='white')
        sheet.save(folder / f'sheet-{batch//60:03d}.jpg', quality=90)
    return entries


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {'policy': 'iPad TouchGameplay composition and interaction; preserved iPad asset/layout proportions. Encoded footage is stretched. Captures are unwarped source pixels.', 'decoder': subprocess.check_output([str(FFMPEG), '-version'], text=True).splitlines()[0], 'clips': []}
    sources = json.loads((VIDEOS / 'video-manifest.json').read_text())
    for index, source in enumerate(sources):
        path = VIDEOS / source['filename']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256']
        folder = DEST / f'clip-{index}'
        entries = capture(path, folder, 1)
        item = {'source': source, 'fps': 1, 'captures': entries, 'sequences': []}
        if 'TouchGameplay' in path.name:
            for name, start, end in SEGMENTS:
                sequence = capture(path, folder / name, 15, start, end-start)
                item['sequences'].append({'name': name, 'fps': 15, 'start': start, 'end': end, 'captures': sequence})
        manifest['clips'].append(item)
        print(path.name, len(entries), sum(len(s['captures']) for s in item['sequences']), flush=True)
        (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')


if __name__ == '__main__':
    main()
