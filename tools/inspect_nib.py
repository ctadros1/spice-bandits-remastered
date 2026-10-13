#!/usr/bin/env python3
"""Read preserved NIBArchive geometry without loading UIKit or modifying inputs.

Format reference: https://github.com/matsmattsson/nibsqueeze/blob/master/NibArchive.md
This small reader is independent of nibarchive's implementation. Research output
is excluded from the shipped game; object references remain explicit.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path


def decode(path):
    raw = Path(path).read_bytes()
    assert raw[:10] == b'NIBArchive'
    version, coder, no, oo, nk, ok, nv, ov, nc, oc = struct.unpack_from('<10I', raw, 10)
    cursor = 50

    def read(n):
        nonlocal cursor
        result = raw[cursor:cursor+n]
        assert len(result) == n
        cursor += n
        return result

    def varint():
        result, shift = 0, 0
        while True:
            byte = read(1)[0]
            result |= (byte & 127) << shift
            if byte & 128:
                return result
            shift += 7
            assert shift < 35

    assert cursor == oo
    objects = [(varint(), varint(), varint()) for _ in range(no)]
    assert cursor == ok
    keys = [read(varint()).decode('utf-8') for _ in range(nk)]
    assert cursor == ov
    values = []
    scalar_formats = {0: '<b', 1: '<h', 2: '<i', 3: '<q', 6: '<f', 7: '<d'}
    for _ in range(nv):
        key, kind = varint(), read(1)[0]
        if kind in scalar_formats:
            fmt = scalar_formats[kind]
            value = struct.unpack(fmt, read(struct.calcsize(fmt)))[0]
        elif kind in (4, 5):
            value = kind == 4
        elif kind == 8:
            data = read(varint())
            if keys[key] in ('UIBounds', 'UICenter') and data[0] == 6:
                value = list(struct.unpack('<' + 'f'*((len(data)-1)//4), data[1:]))
            elif keys[key] == 'NS.bytes':
                value = data.decode('utf-8', errors='replace')
            else:
                value = {'bytes_hex': data.hex()}
        elif kind == 9:
            value = None
        elif kind == 10:
            value = {'ref': struct.unpack('<I', read(4))[0]}
            assert value['ref'] < no
        else:
            raise ValueError(kind)
        values.append((keys[key], value))
    assert cursor == oc
    classes = []
    for _ in range(nc):
        length, extras = varint(), varint()
        read(extras*4)
        classes.append(read(length).rstrip(b'\0').decode('utf-8'))
    assert cursor == len(raw)
    result = []
    for index, (class_id, first, count) in enumerate(objects):
        assert first+count <= nv
        properties = {}
        for key, value in values[first:first+count]:
            if key in properties:
                # NSArray uses repeated NS.object keys; retain order.
                previous = properties[key]
                properties[key] = previous + [value] if isinstance(previous, list) else [previous, value]
            else:
                properties[key] = value
        result.append({'id': index, 'class': classes[class_id], 'properties': properties})
    return {'source': str(path), 'sha256': hashlib.sha256(raw).hexdigest(),
            'version': version, 'coder': coder, 'objects': result}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('output')
    args = parser.parse_args()
    decoded = decode(args.source)
    Path(args.output).write_text(json.dumps(decoded, indent=2)+'\n')
    print(f"Validated {len(decoded['objects'])} objects; all section boundaries and references are in bounds.")
