"""Execute TutorialView afterClose with explicit tutorial kind/controller stubs.

Only original afterClose instructions execute. Objective-C lookups, controller
identity, notifications and menu delivery are recorded stubs. No UIKit frame,
service session, animation scheduling or whole application is emulated.
"""
from native_creep_reference import *


class CloseProbe(Probe):
    def __init__(self):
        super().__init__()
        symbol = next(s for s in json.load(open('original/analysis/decrypted-symbols.json'))
                      if s['name'] == '_OBJC_IVAR_$_TutorialView.tutorialType' and s['value'])
        self.kind_offset = struct.unpack('<I', self.u.mem_read(symbol['value'], 4))[0]

    def hook(self, u, address, size, data):
        if address == 0x36be6c:
            selector = self.string(u.reg_read(UC_ARM_REG_R1))
            if selector == 'tutorialType':
                self.ret(self.kind)
                return
            if selector == 'postNotificationName:object:userInfo:':
                argument = u.reg_read(UC_ARM_REG_R2)
                self.events.append({'notification': self.string(struct.unpack('<I', u.mem_read(argument + 8, 4))[0])})
            elif selector == 'enterMenu:liveGame:':
                self.events.append({'menu': u.reg_read(UC_ARM_REG_R2), 'live_game': u.reg_read(UC_ARM_REG_R3)})
            self.ret(E + 0x1000)
            return
        super().hook(u, address, size, data)

    def run(self, kind):
        self.kind = kind
        self.events = []
        self.u.mem_write(E, bytes(0x2000))
        self.u.mem_write(E + self.kind_offset, I(kind))
        self.u.reg_write(UC_ARM_REG_SP, STACK - 64)
        self.u.reg_write(UC_ARM_REG_LR, END | 1)
        self.u.reg_write(UC_ARM_REG_R0, E)
        self.u.reg_write(UC_ARM_REG_R1, 0)
        self.u.emu_start(0x66bc9, END, count=100000)
        assert self.u.reg_read(UC_ARM_REG_PC) == END
        return {'events': self.events, 'kind_after': struct.unpack('<I', self.u.mem_read(E + self.kind_offset, 4))[0]}


probe = CloseProbe()
cases = [{'kind': kind, 'result': probe.run(kind)} for kind in range(32)]
record = {'method': __doc__, 'original_sha256': EXPECTED_SHA, 'cases': cases,
          'original_unchanged': hashlib.sha256(EXE.read_bytes()).hexdigest() == EXPECTED_SHA}
Path('tests/fixtures/native-portrait-close-reference.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'cases': len(cases), 'routed': [c for c in cases if c['result']['events']],
                  'original_unchanged': record['original_unchanged']}))
