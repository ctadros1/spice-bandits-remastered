"""Original promotion Update/Close and Render with supplied screen/item state.

The real float32 Interpolate, update and close instructions execute. Device,
GetClick and item update are supplied/recorded stubs. Render executes with
explicit text widths, white constructor palette, five frame textures and one
rank image; C++ string/map,
text color/metrics, GL and draws are recording stubs. This is not an original
UIKit rasterizer, service promotion payload or complete app execution.
"""
from native_creep_reference import *
from collections import deque


class PromotionProbe(Probe):
    def hook(self, u, a, size, data):
        self.trace.append(a)
        r0, r1, r2, r3 = [u.reg_read(r) for r in (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3)]
        if a == 0x36be6c:
            name = self.string(r1)
            if name == 'deviceType': self.ret(2)
            elif name == 'sharedGlobals': self.ret(E + 0x7000)
            elif name == 'enterMenu:liveGame:':
                self.menu_requests.append([r2, r3]); self.ret()
            else: raise RuntimeError('Unexpected selector ' + name)
            return
        if a == 0xa34f0:
            self.item_updates += 1; self.ret(); return
        if a == 0x110c50:
            self.clicks.append([r0, r1, r2, r3]); self.ret(int(self.click)); return
        if a in (0x36ca7c, 0x11512c, 0x1151a0, 0x11515c): self.ret(); return
        if a == 0x36b2ac:
            self.color = list(struct.unpack('<4f', I(r0) + I(r1) + I(r2) + I(r3))); self.ret(); return
        if a == 0x11507c:
            self.draws.append({'kind': 'dim', 'rect': list(struct.unpack('<4f', I(r0) + I(r1) + I(r2) + I(r3))), 'rgba': self.color[:]}); self.ret(); return
        if a in (0x36c04c, 0x36c06c):
            if a == 0x36c04c: self.names[r0] = self.string(r1)
            self.ret(); return
        if a == 0xa18a4:
            key = self.names[r1]; self.ret(self.text_slots[key]); return
        if a == 0x12261c: self.ret(BITS(self.widths[r0])); return
        if a == 0x12262c:
            self.text_alpha[r0] = struct.unpack('<f', I(r1))[0]; self.ret(); return
        if a in (0x1152d0, 0x116c30):
            self.draws.append({'kind': 'image' if a == 0x1152d0 else 'text', 'name': self.objects[r0], 'point': list(struct.unpack('<2f', I(r1) + I(r2))), 'alpha': self.color[3] if a == 0x1152d0 else self.text_alpha[r0]}); self.ret(); return
        if a == 0x36c12c: self.ret(E + 0x30); return
        super().hook(u, a, size, data)

    def initialize(self, viewport=(1024, 768)):
        self.trace = deque(maxlen=20); self.names = {}; self.text_slots = {}; self.widths = {}; self.objects = {}; self.text_alpha = {}
        self.menu_requests = []; self.clicks = []; self.item_updates = 0; self.draws = []; self.color = [1] * 4; self.click = False
        self.u.mem_write(E, bytes(0x8000)); self.u.mem_write(STACK - 4096, bytes(8192))
        self.u.mem_write(0x47e410, F(1) * 4)  # Color::WHITE, populated by static initialization in the app.
        self.u.mem_write(0x40a20c, I(MEMORY + 80000)); self.u.mem_write(0x40a204, I(MEMORY + 80004)); self.u.mem_write(MEMORY + 80000, I(viewport[0]) + I(viewport[1]))
        self.u.mem_write(E + 4, I(647) + I(528)); self.u.mem_write(E + 0x5c, I(E + 0x4000) + I(E + 0x4000))

    def call(self, address, args, stack_args=()):
        self.u.reg_write(UC_ARM_REG_SP, STACK - 64); self.u.reg_write(UC_ARM_REG_LR, END | 1)
        for r, v in zip((UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3), args): self.u.reg_write(r, v)
        self.u.mem_write(STACK - 64, b''.join(I(v) for v in stack_args) + bytes(16))
        try: self.u.emu_start(address | 1, END, count=100000)
        except UcError: print('promotion probe failed', hex(self.u.reg_read(UC_ARM_REG_PC)), list(map(hex, self.trace))); raise
        assert self.u.reg_read(UC_ARM_REG_PC) == END

    def state(self):
        return {**{k: bool(self.u.mem_read(E + o, 1)[0]) for k, o in [('visible', 0), ('can_close', 1), ('opening', 2), ('closing', 3), ('finished', 0xa1)]},
                'alpha': struct.unpack('<f', self.u.mem_read(E + 12, 4))[0], 'phase': struct.unpack('<f', self.u.mem_read(E + 16, 4))[0]}

    def sequence(self, steps, close_at=None, item_pressed=False, click=False):
        self.initialize(); self.u.mem_write(E, bytes([0, 1, 1, 0])); self.click = click
        self.u.mem_write(E + 0x5c, I(E + 0x4000) + I(E + 0x4004)); self.u.mem_write(E + 0x4000, I(E + 0x4100)); self.u.mem_write(E + 0x413c, bytes([item_pressed]))
        frames = []
        for index, dt in enumerate(steps):
            if index == close_at: self.call(0xa5760, [E, 1])
            self.call(0xa55bc, [E, BITS(dt), 100, 200], [0, 0, 0])
            frames.append({'dt_ms': dt, 'state': self.state(), 'menu_requests': self.menu_requests[:], 'clicks': len(self.clicks), 'item_updates': self.item_updates})
        return {'steps': steps, 'close_at': close_at, 'item_pressed': item_pressed, 'click': click, 'frames': frames}

    def render(self, viewport, alpha, rewards, title_width):
        self.initialize(viewport); self.u.mem_write(E, b'\x01'); self.u.mem_write(E + 12, F(alpha)); self.u.mem_write(E + 0x74, F(1)); self.u.mem_write(E + 0xa4, I(rewards[0]) + I(rewards[1]))
        for index, name in enumerate(['frame1', 'frame2', 'frame3', 'shadow1', 'shadow2']):
            obj = E + 0x1000 + index * 0x100; self.u.mem_write(E + 0x18 + index * 4, I(obj)); self.objects[obj] = name
        for index, key in enumerate(['title', 'description', 'spice', 'upgrade_label', 'new_stuff']):
            obj = E + 0x2000 + index * 0x100; slot = E + 0x3000 + index * 4
            self.text_slots[key] = slot; self.u.mem_write(slot, I(obj)); self.objects[obj] = key; self.widths[obj] = title_width if key == 'title' else 200
        # One explicit image in the original red-black map traversal.
        self.u.mem_write(E + 0x40, I(1)); self.u.mem_write(E + 0x38, I(E + 0x5000)); self.u.mem_write(E + 0x5014, I(E + 0x5100)); self.u.mem_write(E + 0x5138, I(E + 0x98)); self.objects[E + 0x5100] = 'rank'
        self.call(0xa488c, [E])
        return {'viewport': viewport, 'alpha': alpha, 'spice': rewards[0], 'points': rewards[1], 'title_width': title_width, 'origin': list(struct.unpack('<2f', self.u.mem_read(E + 0x98, 8))), 'draws': self.draws}


def main():
    p = PromotionProbe()
    sequences = [p.sequence(steps, close_at, pressed, click) for steps in [[0, 175, 175, 350, 0, 175, 175, 350, 1], [16.667] * 100, [1, 99, 50, 600, 900]] for close_at in [None, 1, 4] for pressed, click in [(False, False), (False, True), (True, True)]]
    renders = [p.render(viewport, alpha, rewards, width) for viewport in [(1024, 768), (1025, 769), (1280, 960)] for alpha in [0, .25, 1] for rewards in [(0, 0), (5, 0), (0, 3), (5, 3)] for width in [180, 181.5]]
    record = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'sequences': sequences, 'renders': renders, 'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
    Path('tests/fixtures/native-promotion-reference.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'sequences': len(sequences), 'frames': sum(len(c['frames']) for c in sequences), 'renders': len(renders), 'original_unchanged': record['original_unchanged']}))


if __name__ == '__main__': main()
