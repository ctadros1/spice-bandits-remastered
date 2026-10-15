"""Original mine/portal rendering and map placement guards with explicit records.

The original ARM branches, float colors, bar dimensions and cell/owner guards
execute. OpenGL, quad rendering and animator rendering are recorded stubs.
Map pointers, flags, sleep duration and actor state are fixture inputs; this
does not execute original animation updates, input, rasterization or the app.
"""
from native_creep_reference import *


class MagicProbe(Probe):
    def hook(self, u, address, size, data):
        if address == 0x36b2ac:
            self.color = [struct.unpack('<f', I(u.reg_read(r)))[0] for r in
                          (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)]
            self.ret()
            return
        if address == 0x11515c:
            self.blends.append([u.reg_read(UC_ARM_REG_R0), u.reg_read(UC_ARM_REG_R1)])
            self.ret()
            return
        if address == 0x11507c:
            rect = [struct.unpack('<f', I(u.reg_read(r)))[0] for r in
                    (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)]
            self.bars.append({'rect': rect, 'color': self.color[:]})
            self.ret()
            return
        if address == 0x10f54c:
            self.actors.append({'animator': u.reg_read(UC_ARM_REG_R0), 'color': self.color[:]})
            self.ret()
            return
        super().hook(u, address, size, data)

    def call(self, address, args):
        self.u.reg_write(UC_ARM_REG_SP, STACK - 64)
        self.u.reg_write(UC_ARM_REG_LR, END | 1)
        for r, value in zip((UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3), args):
            self.u.reg_write(r, value)
        self.u.emu_start(address | 1, END, count=100000)
        assert self.u.reg_read(UC_ARM_REG_PC) == END

    def render(self, kind, active, state, sleep, light):
        self.u.mem_write(E, bytes(0x1000))
        self.u.mem_write(E + 0x40, bytes([active]))
        self.u.mem_write(E + 0x34, F(light))
        self.u.mem_write(E + 0x4c, F(120) + F(170))
        self.color = []; self.bars = []; self.actors = []; self.blends = []
        if kind == 'mine':
            self.u.mem_write(E + 0x60, I(sleep) + I(state))
            self.u.mem_write(E + 0x80, I(E + 0x200) + I(E + 0x300))
            self.u.mem_write(0x47c490, I(5000))
            self.call(0x9b328, [E])
        else:
            self.u.mem_write(E + 0x58, I(state) + I(E + 0x200))
            self.call(0x9c77c, [E])
        return {'actors': self.actors, 'bars': self.bars, 'blends': self.blends}

    def placement(self, kind, cell, buildable, walkable, owner, player):
        self.u.mem_write(E, bytes(0x4000))
        map_ptr, hex_ptr, rows, pointers, record, actor = [E + v for v in
                                                       (0, 0x400, 0x800, 0x900, 0x1000, 0x2000)]
        self.u.mem_write(map_ptr + 0x74, I(hex_ptr))
        self.u.mem_write(hex_ptr, I(rows))
        self.u.mem_write(hex_ptr + 0x24, I(1) + I(1))
        self.u.mem_write(rows, I(pointers))
        self.u.mem_write(pointers, I(record))
        self.u.mem_write(record + 0x18, bytes([walkable, buildable]))
        self.u.mem_write(record + 0x108, I(owner))
        self.u.mem_write(actor + 0x44, struct.pack('<2i', *cell))
        self.call(0x103b80 if kind == 'mine' else 0x103bec, [map_ptr, actor, player])
        return bool(self.u.reg_read(UC_ARM_REG_R0) & 255)


probe = MagicProbe()
renders = []
for active in (0, 1):
    for state in (0, 1, 2, 3):
        for sleep in (0, 2500, 5000):
            for light in (0.6, 1):
                renders.append({'kind': 'mine', 'active': active, 'state': state, 'sleep': sleep,
                                'light': light, 'result': probe.render('mine', active, state, sleep, light)})
for active in (0, 1):
    for state in (0, 2, 3, 4):
        renders.append({'kind': 'portal', 'active': active, 'state': state,
                        'result': probe.render('portal', active, state, 0, 1)})
placements = []
for kind in ('mine', 'portal'):
    for buildable, walkable in ((0, 0), (0, 1), (1, 0), (1, 1)):
        for owner in (0, 1, 2):
            for player in (1, 2):
                for cell in ((0, 0), (-1, 0), (0, 1)):
                    placements.append({'kind': kind, 'buildable': buildable, 'walkable': walkable,
                                       'owner': owner, 'player': player, 'cell': cell,
                                       'result': probe.placement(kind, cell, buildable, walkable, owner, player)})
record = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'renders': renders, 'placements': placements,
          'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
Path('tests/fixtures/native-magic-view-reference.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'renders': len(renders), 'placements': len(placements),
                  'original_unchanged': record['original_unchanged']}))
