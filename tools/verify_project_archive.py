#!/usr/bin/env python3
"""Check every snapshot part and every archived entry without extracting files."""
import argparse
import hashlib
import json
import stat
from pathlib import Path
import tarfile


def digest(file):
    result = hashlib.sha256()
    for block in iter(lambda: file.read(1024 * 1024), b''):
        result.update(block)
    return result.hexdigest()


class JoinedParts:
    def __init__(self, paths):
        self.paths = iter(paths)
        self.file = None

    def read(self, size):
        result = bytearray()
        while len(result) < size:
            if self.file is None:
                path = next(self.paths, None)
                if path is None:
                    break
                self.file = path.open('rb')
            block = self.file.read(size - len(result))
            if block:
                result.extend(block)
            else:
                self.file.close()
                self.file = None
        return bytes(result)

    def close(self):
        if self.file:
            self.file.close()


def verify(directory):
    parts = json.loads((directory / 'PARTS.json').read_text())['parts']
    paths = []
    for part in parts:
        path = directory / part['name']
        assert path.parent == directory and path.is_file(), part['name']
        assert path.stat().st_size == part['bytes'], part['name']
        with path.open('rb') as file:
            assert digest(file) == part['sha256'], part['name']
        paths.append(path)
        print(f'Part verified: {path.name}', flush=True)
    payload = (directory / 'PROJECT-SNAPSHOT-MANIFEST.json').read_bytes()
    manifest = json.loads(payload)
    expected = {entry['path']: entry for entry in manifest['files']}
    assert len(expected) == len(manifest['files']), 'Duplicate manifest paths'
    seen = set()
    regular, total = 0, 0
    joined = JoinedParts(paths)
    try:
        with tarfile.open(fileobj=joined, mode='r|gz') as tar:
            for member in tar:
                assert member.name not in seen, member.name
                seen.add(member.name)
                if member.name == 'PROJECT-SNAPSHOT-MANIFEST.json':
                    assert tar.extractfile(member).read() == payload, 'Embedded manifest differs'
                    continue
                entry = expected[member.name]
                # tar headers contain permission bits; Python gettarinfo on
                # some versions retains stat's file-type bits in the manifest.
                assert member.mode == stat.S_IMODE(entry['mode']), member.name
                if entry['type'] == 'file':
                    assert member.isfile() and member.size == entry['bytes'], member.name
                    with tar.extractfile(member) as file:
                        assert digest(file) == entry['sha256'], member.name
                    regular += 1
                    total += member.size
                elif entry['type'] == 'directory':
                    assert member.isdir(), member.name
                elif entry['type'] == 'symlink':
                    assert member.issym() and member.linkname == entry['target'], member.name
                elif entry['type'] == 'hardlink':
                    assert member.islnk() and member.linkname == entry['target'], member.name
                else:
                    raise AssertionError(entry)
                if len(seen) % 2000 == 0:
                    print(f'Archive verified: {len(seen)} entries', flush=True)
    finally:
        joined.close()
    assert seen == set(expected) | {'PROJECT-SNAPSHOT-MANIFEST.json'}, 'Missing/extra entries'
    report = {'passed': True, 'parts': len(parts), 'entries': len(expected),
              'regular_files': regular, 'regular_bytes': total,
              'manifest_sha256': hashlib.sha256(payload).hexdigest(),
              'scope': 'Every local part hash, archived regular-file hash, entry type, mode and link target; no extraction or original-device gameplay.'}
    (directory / 'local-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    verify(parser.parse_args().directory.resolve())
