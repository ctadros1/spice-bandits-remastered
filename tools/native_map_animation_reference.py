"""Original animated map-object render/keyframe math on explicit frame records.

Original CAnimatedObject::Render, CKeyFrameAnimator::Update, frame selection
and interpolation execute. RenderCenterQuad is a recorded stub; texture,
frame vectors, loop/ease flags and elapsed render time are explicit inputs.
This does not execute the XML loader, original sampler/compositor or app.
"""
from native_creep_reference import *
import xml.etree.ElementTree as ET


class MapAnimationProbe(Probe):
    def hook(self, u, address, size, data):
        if address == 0x115b30:
            self.draw = [struct.unpack('<f', I(u.reg_read(r)))[0] for r in
                         (UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)]
            self.ret()
            return
        super().hook(u, address, size, data)

    def run(self, definition, steps):
        self.u.mem_write(E, bytes(0x3000))
        self.u.mem_write(E, I(E + 0x2000) + F(definition['x']) + F(definition['y']))
        key, pointers = E + 0x10, E + 0x1000
        self.u.mem_write(key + 8, bytes([int(definition['anim_loop'])]))
        self.u.mem_write(key + 0x12, bytes([int(definition['anim_ease'])]))
        self.u.mem_write(key + 0xc, F(definition['anim_speed']))
        self.u.mem_write(key + 0x14, I(pointers) + I(pointers + len(definition['frames']) * 4))
        for i, frame in enumerate(definition['frames']):
            record = E + 0x1100 + i * 16
            self.u.mem_write(pointers + i * 4, I(record))
            self.u.mem_write(record, F(frame['angle']) + b''.join(F(v) for v in frame['pos']))
        rows = []
        for dt in steps:
            self.draw = None
            self.u.reg_write(UC_ARM_REG_SP, STACK - 64)
            self.u.reg_write(UC_ARM_REG_LR, END | 1)
            self.u.reg_write(UC_ARM_REG_R0, E)
            self.u.reg_write(UC_ARM_REG_R1, BITS(dt))
            self.u.emu_start(0x104255, END, count=100000)
            assert self.u.reg_read(UC_ARM_REG_PC) == END
            rows.append({'dt_ms': dt, 'draw': self.draw, 'phase': struct.unpack('<f', self.u.mem_read(key, 4))[0],
                         'index': struct.unpack('<I', self.u.mem_read(key + 4, 4))[0],
                         'stopped': bool(self.u.mem_read(key + 0x10, 1)[0]),
                         'initialized': bool(self.u.mem_read(key + 0x11, 1)[0])})
        return rows


source = Path('original/game-files/ipa-1.14/Payload/Tower.app/maps/lobby_map.xml')
root = ET.fromstring(source.read_text().replace('/n<xml>', '<xml>'))
definitions = []
for obj in root.findall('.//animated_objects/obj'):
    definitions.append({'name': obj.findtext('texture/filename'),
                        'x': int(obj.findtext('x')), 'y': int(obj.findtext('y')),
                        'anim_loop': int(obj.findtext('anim_loop', '0')),
                        'anim_ease': int(obj.findtext('anim_ease', '0')),
                        'anim_speed': float(obj.findtext('anim_speed', '0')),
                        'frames': [{'pos': [float(v) for v in f.findtext('pos').split()],
                                    'angle': float(f.findtext('angle'))} for f in obj.findall('frames/f')]})
for loop in (0, 1):
    for ease in (0, 1):
        definitions.append({'name': 'explicit-three-frame-fixture', 'x': 120, 'y': 170,
                            'anim_loop': loop, 'anim_ease': ease, 'anim_speed': 0.001,
                            'frames': [{'pos': [0, 1], 'angle': -15}, {'pos': [5, -2], 'angle': 35},
                                       {'pos': [-20, 11], 'angle': 10}]})
probe = MapAnimationProbe()
steps = [0] + [16.67] * 12 + [500] * 24 + [1500, 100000, 0, 16.67, 16.67]
cases = [{'definition': d, 'frames': probe.run(d, steps)} for d in definitions]
record = {'method': __doc__, 'original_sha256': EXPECTED_SHA,
          'xml_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'cases': cases,
          'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
Path('tests/fixtures/native-map-animation-reference.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'cases': len(cases), 'frames': sum(len(c['frames']) for c in cases),
                  'original_unchanged': record['original_unchanged']}))
