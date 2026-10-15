"""Original build-page arrow/marker visibility and dock-relative anchors.

Execute Page01_EndCondition0xb8078 with explicit tower presence, device and
orientation. C++ strings/maps, tower lookup and Objective-C device lookup are
stubs; texture/text records contain explicit initial visibility. No renderer,
GUI construction, camera delivery or application session is emulated.
"""
from native_creep_reference import *

CELLS = [(7, 4), (6, 7), (8, 6), (11, 3)]


class ArrowProbe(Probe):
    def hook(self, u, address, size, data):
        r0, r1 = [u.reg_read(r) for r in (UC_ARM_REG_R0, UC_ARM_REG_R1)]
        if address == 0x36be6c:
            self.ret(self.device if self.string(r1) == 'deviceType' else E + 0x1000)
            return
        if address == 0x36c04c:
            self.cpp_strings[r0] = self.string(r1)
            self.ret(r0)
            return
        if address in (0x36c06c, 0x36ca7c):
            self.ret()
            return
        if address == 0xb90dc:
            name = self.cpp_strings[r1]
            if name not in self.objects:
                slot = MEMORY + 10000 + len(self.objects) * 512
                obj, texture, text = slot + 4, slot + 32, slot + 160
                u.mem_write(slot, I(obj))
                u.mem_write(obj + 4, I(texture))
                u.mem_write(obj + 8, I(text))
                u.mem_write(texture + 0x37, b'\x01')
                u.mem_write(text + 0x5e, b'\x01')
                self.objects[name] = (slot, texture, text)
            self.ret(self.objects[name][0])
            return
        if address == 0xe9784:
            cell = (r0, r1)
            self.ret(E + 0x3000 if cell in self.built else 0)
            return
        super().hook(u, address, size, data)

    def run(self, mask, device, landscape):
        self.device = device
        self.built = {cell for i, cell in enumerate(CELLS) if mask & (1 << i)}
        self.cpp_strings = {}
        self.objects = {}
        self.u.mem_write(E, bytes(0x4000))
        self.u.mem_write(MEMORY + 10000, bytes(20000))
        self.u.mem_write(0x40a214, I(MEMORY + 90000))
        self.u.mem_write(MEMORY + 90000, bytes([int(landscape)]))
        tutorial = E + 0x2000
        self.u.mem_write(tutorial + 4, I(E + 0x2400))
        self.u.mem_write(tutorial + 8, I(3))
        self.u.mem_write(E + 0x238, I(1))
        self.u.reg_write(UC_ARM_REG_SP, STACK - 64)
        self.u.reg_write(UC_ARM_REG_LR, END | 1)
        self.u.reg_write(UC_ARM_REG_R0, E)
        self.u.reg_write(UC_ARM_REG_R1, tutorial)
        self.u.emu_start(0xb8079, END, count=100000)
        assert self.u.reg_read(UC_ARM_REG_PC) == END
        records = {}
        for name, (_, texture, text) in self.objects.items():
            records[name] = {'image_visible': bool(self.u.mem_read(texture + 0x37, 1)[0]),
                             'text_visible': bool(self.u.mem_read(text + 0x5e, 1)[0]),
                             'image_position': list(struct.unpack('<2f', self.u.mem_read(texture + 0x20, 8))),
                             'text_position': list(struct.unpack('<2f', self.u.mem_read(text + 0x54, 8)))}
        return {'objects': records, 'pending': bool(self.u.mem_read(tutorial + 0xc, 1)[0]),
                'page_after': struct.unpack('<I', self.u.mem_read(tutorial + 8, 4))[0]}


probe = ArrowProbe()
cases = [{'built_mask': mask, 'device': device, 'landscape': landscape,
          'result': probe.run(mask, device, landscape)}
         for mask in range(16) for device in (1, 2) for landscape in (False, True)]
record = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'cells': CELLS, 'cases': cases,
          'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
Path('tests/fixtures/native-tutorial-arrow-reference.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'cases': len(cases), 'tablet_landscape': [c for c in cases if c['device'] == 2 and c['landscape']][:2],
                  'original_unchanged': record['original_unchanged']}))
