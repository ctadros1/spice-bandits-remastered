"""Original RenderGreenRangeOval colors and oval submissions with explicit alpha.

Original arithmetic/branching executes. OpenGL/blending/oval vertex rendering
are recorded stubs. Resource range, bonus, hex distance and proportion are
explicit inputs. No original compositor or whole game is executed.
"""
from native_creep_reference import *


class OvalProbe(Probe):
    def hook(self, u, address, size, data):
        if address == 0x36b2ac:
            self.color = [struct.unpack('<f', I(u.reg_read(r)))[0] for r in (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)]
            self.ret()
            return
        if address == 0x11515c:
            self.ret()
            return
        if address in (0x114b74, 0x114a84):
            args = [struct.unpack('<f', I(u.reg_read(r)))[0] for r in (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)]
            self.draws.append({'filled': address == 0x114b74, 'origin': args[:2], 'axes': args[2:], 'color': self.color[:]})
            self.ret()
            return
        super().hook(u, address, size, data)

    def run(self, alpha, distance, radius, bonus, visible):
        self.u.mem_write(E, bytes(0x2000))
        self.u.mem_write(E + 0x54, bytes([visible]))
        self.u.mem_write(E + 0x4c, F(120) + F(170))
        self.u.mem_write(E + 0xf0, I(E + 0x1000))
        self.u.mem_write(E + 0x1024, F(radius))
        self.u.mem_write(E + 0xfc, F(bonus))
        self.u.mem_write(0x40a284, I(MEMORY + 90000))
        self.u.mem_write(0x40a288, I(MEMORY + 90004))
        self.u.mem_write(MEMORY + 90000, F(distance) + F(1.440000057220459))
        self.draws = []
        self.color = []
        self.u.reg_write(UC_ARM_REG_SP, STACK - 64)
        self.u.reg_write(UC_ARM_REG_LR, END | 1)
        self.u.reg_write(UC_ARM_REG_R0, E)
        self.u.reg_write(UC_ARM_REG_R1, BITS(alpha))
        self.u.emu_start(0xe8131, END, count=100000)
        assert self.u.reg_read(UC_ARM_REG_PC) == END
        return self.draws


probe = OvalProbe()
cases = [{'alpha': alpha, 'distance': distance, 'range': radius, 'bonus': bonus, 'visible': visible,
          'draws': probe.run(alpha, distance, radius, bonus, visible)}
         for alpha in (0, 0.5, 1) for distance, radius, bonus in ((0.062, 2000, 0), (0.064, 5000, 125))
         for visible in (0, 1)]
record = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'cases': cases,
          'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
Path('tests/fixtures/native-preview-oval-reference.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'cases': len(cases), 'draws': sum(len(c['draws']) for c in cases), 'original_unchanged': record['original_unchanged']}))
