"""Execute original result update clocks with explicit initial delay/flags.

Particle factories, sound loads and the empty emitter vector are stubs. The
original constructor/Open/service callback initialization is not executed.
"""
from native_creep_reference import *
class RewardProbe(Probe):
 def hook(self,u,a,size,data):
  if a in [0x111834,0x120520,0x36ca7c]:self.ret(0);return
  super().hook(u,a,size,data)
 def run(self,delay,state,steps):
  self.u.mem_write(E,bytes(0x200));self.u.mem_write(E,I(state));self.u.mem_write(E+0x9c,b'\x01');self.u.mem_write(E+0xa0,F(delay))
  frames=[]
  for dt in steps:
   self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
   self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,BITS(dt))
   self.u.emu_start(0xbc08d,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
   vals={key:struct.unpack('<f',self.u.mem_read(E+off,4))[0] for key,off in [('alpha',0x14),('open_phase',0x18),('delay',0xa0),('xp_phase',0xa4),('medal_clock',0xac),('spice_phase',0xb4)]}
   vals['state']=struct.unpack('<I',self.u.mem_read(E,4))[0];frames.append({'dt_ms':dt,'fields':vals})
  return frames
probe=RewardProbe();cases=[]
for delay in [0,-2]:
 for state in [0,1]:
  for steps in [[30]*350,[16.667]*630,[0,700,1300,2000,500,2500,1500]]:cases.append({'initial_delay':delay,'initial_state':state,'frames':probe.run(delay,state,steps)})
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-reward-clock-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
