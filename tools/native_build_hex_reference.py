"""Original RenderHexLinesInRange with explicit small grid/building records.

Original range filtering, distance/opacity and vertex generation execute.
Render-buffer submissions, OpenGL calls and base identities are recorded
stubs; grid coordinates/build flags/hex corners are explicit fixture inputs.
No live path validation, renderer/compositor or full application executes.
"""
from native_creep_reference import *


class HexProbe(Probe):
    def hook(self, u, address, size, data):
        if address in (0x1168d8, 0x116a54, 0x1169e4, 0x116adc, 0x36b2ac):
            self.ret()
            return
        if address == 0x116a60:
            pointer = u.reg_read(UC_ARM_REG_R1)
            vertices = []
            for i in range(6):
                values = struct.unpack('<2f4B', u.mem_read(pointer + i * 12, 12))
                vertices.append({'position': list(values[:2]), 'color_bytes': list(values[2:])})
            self.quads.append(vertices)
            self.ret()
            return
        if address == 0x1168e4:
            sp = u.reg_read(UC_ARM_REG_SP)
            words = b''.join(I(u.reg_read(r)) for r in (UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)) + bytes(u.mem_read(sp, 36))
            values = list(struct.unpack('<12f', words))
            self.lines.append({'start': values[:2], 'start_color': values[2:6],
                               'end': values[6:8], 'end_color': values[8:12]})
            self.ret()
            return
        super().hook(u, address, size, data)

    def run(self, radius, active, positioned, valid, base_blocked, offset):
        self.u.mem_write(E, bytes(0x6000))
        self.u.mem_write(MEMORY + 10000, bytes(20000))
        rows = E + 0x2000
        self.u.mem_write(E, I(rows))
        self.u.mem_write(E + 0x24, I(3) + I(3))
        corners = [(0, 0), (44, 0), (66, 31), (44, 62), (0, 62), (-22, 31)]
        self.u.mem_write(E + 0x38, b''.join(struct.pack('<2i', *p) for p in corners))
        cells = []
        for y in range(3):
            pointers = E + 0x2100 + y * 16
            self.u.mem_write(rows + y * 12, I(pointers))
            for x in range(3):
                cell = E + 0x3000 + (y * 3 + x) * 0x100
                self.u.mem_write(pointers + x * 4, I(cell))
                top = (22 + x * 66, y * 62 + (x % 2) * 31)
                center = (top[0] + 22, top[1] + 31)
                buildable = (x + y) % 2 == 0
                self.u.mem_write(cell, struct.pack('<4i2f', *top, x, y, *center))
                self.u.mem_write(cell + 0x19, bytes([int(buildable)]))
                cells.append({'cell': [x, y], 'top': list(top), 'center': list(center), 'buildable': buildable})
        building = E + 0x1000
        origin = cells[4]['center']
        self.u.mem_write(building + 0x40, bytes([active, positioned, valid, 0]))
        self.u.mem_write(building + 0x44, I(1) + I(1) + struct.pack('<2f', *origin))
        base_vector = MEMORY + 10000
        self.u.mem_write(0x40a110, I(base_vector))
        if base_blocked:
            pointer, base = MEMORY + 10100, MEMORY + 10200
            self.u.mem_write(base_vector, I(pointer) + I(pointer + 4))
            self.u.mem_write(pointer, I(base))
            self.u.mem_write(base + 0x44, I(1) + I(1))
        self.u.mem_write(E + 0xb4, I(4))
        self.quads = []
        self.lines = []
        self.u.reg_write(UC_ARM_REG_SP, STACK - 64)
        self.u.mem_write(STACK - 64, I(offset[1]))
        self.u.reg_write(UC_ARM_REG_LR, END | 1)
        for r, value in zip((UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3),
                            (E, building, BITS(radius), offset[0])):
            self.u.reg_write(r, value)
        self.u.emu_start(0x1043b5, END, count=1000000)
        assert self.u.reg_read(UC_ARM_REG_PC) == END
        return {'origin': origin, 'cells': cells, 'corners': corners, 'quads': self.quads, 'lines': self.lines,
                'cache_counter': struct.unpack('<I', self.u.mem_read(E + 0xb4, 4))[0]}


probe = HexProbe()
cases = []
for radius in (70, 248):
    for active, positioned, valid in ((0, 1, 1), (0, 1, 0), (0, 0, 1), (1, 1, 1)):
        for blocked, offset in ((False, (0, 0)), (True, (-30, 17))):
            result = probe.run(radius, active, positioned, valid, blocked, offset)
            cases.append({'radius': radius, 'active': active, 'positioned': positioned, 'valid': valid,
                          'base_blocked': blocked, 'offset': offset, 'result': result})
record = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'cases': cases,
          'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
Path('tests/fixtures/native-build-hex-reference.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'cases': len(cases), 'quads': sum(len(c['result']['quads']) for c in cases),
                  'lines': sum(len(c['result']['lines']) for c in cases),
                  'original_unchanged': record['original_unchanged']}))
