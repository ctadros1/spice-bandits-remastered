"""Execute original UpdateWaves/RenderWaves for explicit early-collapse input.

Input flag is seeded, room counter advances externally, gameplay ProcessWaves
is omitted. Widget offset/GL/draw/Unwind calls are stubs. Ends on the native
first-quad threshold that ProcessWaves uses for launch, or ordinary deadline.
"""
from native_wave_reference import *
class CollapseProbe(WaveProbe):
 def hook(self,u,a,size,data):
  if a==0xd74d0:self.ret(0);return
  if a==0x36ca7c:self.ret();return
  super().hook(u,a,size,data)
 def run(self,current,elapsed,steps):
  self.sample(current,elapsed,skip_fields={'active':True})
  self.u.mem_write(E+0x2ac,I(1));self.u.mem_write(E+0x464,I(E+0xc000));self.u.mem_write(E+0xc098,F(1024))
  frames=[]
  for dt in steps:
   elapsed+=int(dt);self.u.mem_write(E+0x22c,I(elapsed))
   self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,BITS(dt))
   self.u.emu_start(0xd3721,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
   self.draws=[];self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E)
   self.u.emu_start(0xd811d,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
   fields={k:struct.unpack('<f',self.u.mem_read(E+off,4))[0] for off,k in [(0x250,'distance'),(0x258,'duration'),(0x280,'extra')]}
   fields.update(active=bool(self.u.mem_read(E+0x24e,1)[0]),first=struct.unpack('<i',self.u.mem_read(E+0x278,4))[0])
   frames.append({'dt_ms':dt,'elapsed':elapsed,'fields':fields,'text_draws':[d for d in self.draws if d['kind']=='text']})
   if fields['first']< -39 or elapsed>=5000:break
  return frames
probe=CollapseProbe();cases=[]
for current in [0,1,5]:
 for elapsed in [0,1000,4000,4990]:
  for steps in [[30]*60,[16.67]*120,[0,250,500,1000]]:
   cases.append({'current':current,'initial_elapsed':elapsed,'delay':5000,'total':6,'frames':probe.run(current,elapsed,steps)})
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-wave-collapse-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
