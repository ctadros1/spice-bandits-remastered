"""Bounded original wave-strip draw geometry with explicit room fields.

The original RenderWaves function executes; graphics/text calls are recorded,
not rendered. Counter, current-wave and particle field0xc0 values are
explicit inputs, not a claim that whole-game callback order is recovered.
"""
from native_creep_reference import *
class WaveProbe(Probe):
 def __init__(self):
  self.draws=[]
  super().__init__()
 def hook(self,u,a,size,data):
  r0,r1,r2=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a in [0x36b2ac,0x11515c,0x111880]:self.ret();return
  if a in [0x1152d0,0x116c30]:
   f=lambda value:struct.unpack('<f',I(value))[0]
   self.draws.append({'kind':'quad' if a==0x1152d0 else 'text','object':r0,'x':f(r1),'y':f(r2)})
   self.ret();return
  super().hook(u,a,size,data)
 def sample(self,current,elapsed,total=6,particle_field_c0=None,skip_fields=None):
  self.u.mem_write(E,bytes(0x600));self.draws=[]
  for offset,value in [(0,E+0x1000),(4,E+0x1000+total*4),(0x22c,elapsed),(0x234,5000),(0x238,current),(0x274,60),(0x284,E+0x8000),(0x29c,E+0x9000)]:self.u.mem_write(E+offset,I(value))
  self.u.mem_write(E+0x8008,I(60)+I(26))
  for i in range(total):
   wave=E+0x2000+i*0x100;self.u.mem_write(E+0x1000+i*4,I(wave));self.u.mem_write(wave,bytes(0x100))
   self.u.mem_write(wave+0x40,I(i+1)+I(4)+I(0)+I(E+0x8000)+I(i+1))
  if particle_field_c0 is not None:
   self.u.mem_write(E+0x260,I(E+0xa000)+I(E+0xa004));self.u.mem_write(E+0xa000,I(E+0xb000))
   self.u.mem_write(E+0xb04c,F(60));self.u.mem_write(E+0xb0c0,F(particle_field_c0))
  if skip_fields:
   self.u.mem_write(E+0x24e,bytes([int(skip_fields.get('active',True))]))
   for offset,key in [(0x250,'distance'),(0x258,'duration'),(0x280,'extra')]:self.u.mem_write(E+offset,F(skip_fields.get(key,0)))
  self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E)
  self.u.emu_start(0xd811d,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return [d for d in self.draws if d['kind']=='text']
probe=WaveProbe();cases=[]
for current in [0,1,2,5,6]:
 for elapsed in [0,1,2499,4999]:
  for progress in [None,0,29,30]:cases.append({'current':current,'elapsed':elapsed,'particle_field_c0':progress,'text_draws':probe.sample(current,elapsed,particle_field_c0=progress)})
result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-wave-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'text_draws':sum(len(c['text_draws']) for c in cases),'original_unchanged':result['original_unchanged']}))
