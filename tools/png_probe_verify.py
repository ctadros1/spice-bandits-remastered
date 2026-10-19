"""Read exact saved QA pixels independently of Godot's reported probe fields."""
import json
import sys
from PIL import Image


def main():
    request = json.load(sys.stdin)
    rows = []
    for path in request['paths']:
        with Image.open(path) as source:
            value = source.convert('RGBA')
            rows.append({'size': list(value.size), 'rgba8': [list(value.getpixel(tuple(point))) for point in request['points']]})
    print(json.dumps(rows))


if __name__ == '__main__':
    main()
