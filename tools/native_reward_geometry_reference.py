"""Execute the original medal render loop0xbb7a6..0xbba76.

Explicit source textures and medal slot/fraction replace earlier caller state.
GL, drawing, particle factories/Emit, vector insertion and sound are recording
stubs. Captures geometry, alpha, override fields and once-only burst behavior;
does not execute a complete result screen or original particle rendering.
"""
from native_creep_reference import *
FUNCTIONS={f['name']:f['address'] for f in json.load(open('original/analysis/functions.json'))}
class GeometryProbe(Probe):
 def hook(self,u,a,size,data):
  if a==self.stop:u.emu_stop();return
  r0,r1,r2=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a==0x36b2ac:
   self.alpha=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R3)))[0];self.ret();return
  if a==FUNCTIONS['__Z14RenderQuadFastP14CTextureObjectff']:
   self.draws.append({'rect':[*struct.unpack('<f',I(r1)),*struct.unpack('<f',I(r2)),*struct.unpack('<2i',u.mem_read(r0+8,8))],'alpha':self.alpha});self.ret();return
  if a==0x111834:self.ret(E+0x2000);return
  if a==0x111418:
   self.bursts.append({'point':list(struct.unpack('<2f',u.mem_read(r0+0xa0,8))),'release_interval_seconds':struct.unpack('<f',u.mem_read(r0+8,4))[0],'clock_multiplier':struct.unpack('<f',u.mem_read(r0+0x50,4))[0],'count':r1});self.ret();return
  if a==0x81bb0:self.ret();return
  if a==0xbbf9c:self.booms+=1;self.ret();return
  super().hook(u,a,size,data)
 def run(self,source,slot,fraction,origin,shown=False):
  self.u.mem_write(E,bytes(0x3000));self.draws=[];self.bursts=[];self.booms=0;self.stop=0xbba76
  self.u.mem_write(E+0x14,F(.75));self.u.mem_write(E+0xec,struct.pack('<2i',*origin))
  self.u.mem_write(E+0x78,I(E+0x400));self.u.mem_write(E+0x7c,I(E+0x418))
  for i in range(6):
   medal=E+0x500+i*0x80;tex=medal+0x40
   self.u.mem_write(E+0x400+i*4,I(medal));self.u.mem_write(medal+0x24,I(tex));self.u.mem_write(medal+0x28,bytes([int(shown)]));self.u.mem_write(tex+8,struct.pack('<2i',*source))
  self.u.mem_write(E+0x2004,I(10))
  self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.mem_write(STACK+0x40,I(E));self.u.mem_write(STACK+0x3c,I(slot));self.u.mem_write(STACK+0x38,I(E+0x84))
  self.u.reg_write(UC_ARM_REG_D10,struct.unpack('<Q',F(fraction)*2)[0])
  self.u.emu_start(0xbb7a7,self.stop,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==self.stop
  return {'draws':self.draws,'bursts':self.bursts,'booms':self.booms,'source_restored':all(struct.unpack('<2i',self.u.mem_read(E+0x548+i*0x80,8))==source for i in range(6))}
probe=GeometryProbe();cases=[]
for source in [(54,54),(53,47),(65,59)]:
 for slot in [0,1,5,6]:
  for fraction in [0,.01,.25,.5,.75,1]:
   for shown in [False,True]:
    cases.append({'source':source,'slot':slot,'fraction':fraction,'origin':[188,127],'already_shown':shown,'output':probe.run(source,slot,fraction,(188,127),shown)})
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-reward-geometry-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'original_unchanged':result['original_unchanged']}))
