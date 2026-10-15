#!/usr/bin/env python3
"""Make a private, checksummed project snapshot in release-sized parts.

Includes ignored project files, symlinks and empty directories. Excludes .git,
Finder .DS_Store files and the output directory. Does not follow symlinks.
Run from a quiet project; changing files make the snapshot fail.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[1]


class Parts:
    def __init__(self, directory, limit=1_500_000_000):
        self.directory, self.limit = directory, limit
        self.file = None
        self.entries = []
        self.size = 0
        self.digest = None

    def write(self, data):
        total = len(data)
        while data:
            if self.file is None:
                name = f'project-snapshot.tar.gz.part-{len(self.entries) + 1:03d}'
                self.file = (self.directory / name).open('xb')
                self.digest, self.size = hashlib.sha256(), 0
                self.entries.append({'name': name})
            part = data[:self.limit - self.size]
            self.file.write(part)
            self.digest.update(part)
            self.size += len(part)
            data = data[len(part):]
            if self.size == self.limit:
                self.finish_part()
        return total

    def finish_part(self):
        if self.file is not None:
            self.file.close()
            self.entries[-1].update(bytes=self.size, sha256=self.digest.hexdigest())
            self.file = None

    def flush(self):
        if self.file:
            self.file.flush()


class HashReader:
    def __init__(self, file):
        self.file, self.digest = file, hashlib.sha256()

    def read(self, size=-1):
        data = self.file.read(size)
        self.digest.update(data)
        return data


def snapshot(output):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if list(output.glob('project-snapshot*')):
        raise SystemExit('Snapshot already exists; choose a fresh output directory.')
    paths, skipped = [], []
    for base, dirs, files in os.walk(ROOT, followlinks=False):
        base = Path(base)
        for name in list(dirs):
            p = base / name
            if p == ROOT / '.git' or p.resolve() == output:
                dirs.remove(name)
                continue
            paths.append(p)
            if p.is_symlink():
                dirs.remove(name)
        for name in files:
            p = base / name
            if name == '.DS_Store':
                skipped.append(str(p.relative_to(ROOT)))
            else:
                paths.append(p)
    manifest = {'format': 1, 'scope': 'All project files except .git, output directory and Finder .DS_Store; symlink targets are not followed.',
                'skipped_finder_files': skipped, 'files': []}
    parts = Parts(output)
    with gzip.GzipFile(fileobj=parts, mode='wb', filename='', compresslevel=1, mtime=0) as compressed, \
            tarfile.open(fileobj=compressed, mode='w|', format=tarfile.PAX_FORMAT) as tar:
        for index, p in enumerate(sorted(paths)):
            before = p.lstat()
            name = p.relative_to(ROOT).as_posix()
            info = tar.gettarinfo(str(p), arcname=name)
            entry = {'path': name, 'mode': info.mode}
            if info.isfile():
                with p.open('rb') as file:
                    reader = HashReader(file)
                    tar.addfile(info, reader)
                entry.update(type='file', bytes=info.size, sha256=reader.digest.hexdigest())
            elif info.issym():
                tar.addfile(info)
                entry.update(type='symlink', target=info.linkname)
            elif info.islnk():
                tar.addfile(info)
                entry.update(type='hardlink', target=info.linkname)
            elif info.isdir():
                tar.addfile(info)
                entry.update(type='directory')
            else:
                raise RuntimeError(f'Unsupported special file: {name}')
            after = p.lstat()
            if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                raise RuntimeError(f'Changed during snapshot: {name}')
            manifest['files'].append(entry)
            if index % 1000 == 0:
                print(f'Archived {index}/{len(paths)} entries', flush=True)
        payload = (json.dumps(manifest, indent=2) + '\n').encode()
        info = tarfile.TarInfo('PROJECT-SNAPSHOT-MANIFEST.json')
        info.size, info.mode = len(payload), 0o644
        tar.addfile(info, io.BytesIO(payload))
    parts.finish_part()
    (output / 'PROJECT-SNAPSHOT-MANIFEST.json').write_bytes(payload)
    (output / 'PARTS.json').write_text(json.dumps({'parts': parts.entries}, indent=2) + '\n')
    print(f'Snapshot complete: {len(manifest["files"])} entries, {len(parts.entries)} parts', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    snapshot(parser.parse_args().output)
