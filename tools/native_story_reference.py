"""Execute preserved story glow node animation with explicit starting fields."""
from native_creep_reference import *
class StoryProbe(Probe):
 def hook(self,u,a,size,data):
  if a in [0x115b30,0x36b2ac]:self.ret();return
  super().hook(u,a,size,data)
 def sample(self,initial,dt):
  fields=[*initial['position'],*initial['start'],*initial['direction'],*initial['end'],initial['scale'],initial['phase'],0,initial['alpha'],initial['initial_alpha']]
  self.u.mem_write(E,struct.pack('<13f',*fields)+bytes([int(initial['fade_in']),int(initial['finished']),0,0]))
  self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2],[E,E+0x1000,BITS(dt)]):self.u.reg_write(r,v)
  self.u.emu_start(0xb1965,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  data=struct.unpack('<13f',self.u.mem_read(E,52))
  return {'position':list(data[:2]),'phase':data[9],'alpha':data[11],'initial_alpha':data[12],'fade_in':bool(self.u.mem_read(E+52,1)[0]),'finished':bool(self.u.mem_read(E+53,1)[0])}
probe=StoryProbe();cases=[]
for fade_in in [False,True]:
 for phase in [0,0.25,0.75,0.999,1.1]:
  initial={'position':[18.25,307.75],'start':[18.25,307.75],'direction':[0.1,-0.2],'end':[-9.875,276.325],'scale':1.4,'phase':phase,'alpha':0.45,'initial_alpha':0.45,'fade_in':fade_in,'finished':False}
  for dt in [0,16.667,333,750]:cases.append({'initial':initial,'dt_ms':dt,'result':probe.sample(initial,dt)})
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-story-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'original_unchanged':result['original_unchanged']}))
