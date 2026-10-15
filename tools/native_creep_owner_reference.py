"""Original complete creep before/after owner routing with supplied records.

Executes CCreep::RenderBefore0x7f518 and RenderAfter0x7f55c. Creep resource,
state, missile flags, shooter and sprite/laser vectors are explicit inputs.
Actual shooting-processor, missile, sprite and laser render methods are
recording stubs. No constructor, GPU, physics, lifetime, global owner order
or complete game executes.
"""
from native_map_order_reference import *


class OwnerProbe(OrderProbe):
    def hook(self, u, address, size, data):
        methods = {0x82284: 'shooter-before', 0x81a9c: 'missile',
                   0x121648: 'sprite', 0xde1f8: 'laser'}
        if address in methods:
            actor = u.reg_read(UC_ARM_REG_R0)
            record = {'method': methods[address]}
            if address == 0x81a9c:
                record['label'] = (actor-E-0x4000)//0x200
            self.calls.append(record)
            self.ret()
            return
        super().hook(u, address, size, data)

    def route(self, kind, state, flags_a0, shooter, extras, after):
        self.reset()
        self.calls = []
        self.u.mem_write(E+0x250, I(E+0x1000))
        self.u.mem_write(E+0x1004, I(kind))
        self.u.mem_write(E+0x170, bytes([state]))
        start = E+0x2000
        self.u.mem_write(E+0x368, struct.pack('<2I', start, start+4*len(flags_a0)))
        for i, flag in enumerate(flags_a0):
            missile = E+0x4000+i*0x200
            self.u.mem_write(start+i*4, I(missile))
            self.u.mem_write(missile+0xa0, bytes([flag]))
        if shooter:
            self.u.mem_write(E+0x338, I(E+0x7000))
        if extras:
            self.u.mem_write(E+0x284, struct.pack('<2I', E+0x3000, E+0x3008))
            self.u.mem_write(E+0x3000, struct.pack('<2I', E+0x8000, E+0x8100))
            self.u.mem_write(E+0x340, I(E+0x9000))
        self.invoke(0x7f55c if after else 0x7f518, [E])
        return self.calls


def main():
    probe = OwnerProbe()
    cases = []
    for kind in [0, 1, 2]:
        for state in [0, 2, 3, 4]:
            for flags_a0 in [[], [False], [True, False], [False, True, False]]:
                for shooter in [False, True]:
                    for extras in [False, True]:
                        before = probe.route(kind, state, flags_a0, shooter, extras, False)
                        after = probe.route(kind, state, flags_a0, shooter, extras, True)
                        cases.append({'resource_type': kind, 'state': state,
                                      'missile_flags_a0': flags_a0, 'shooter': shooter,
                                      'extras': extras, 'before': before, 'after': after})
    result = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'cases': cases,
              'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
    Path('tests/fixtures/native-creep-owner-reference.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'cases': len(cases),
                      'calls': sum(len(c['before'])+len(c['after']) for c in cases),
                      'original_unchanged': result['original_unchanged']}))


if __name__ == '__main__':
    main()
