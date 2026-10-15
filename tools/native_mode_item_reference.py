"""Execute the original level item's initial animation block.

Stops at0x85126 before configuration, services and text updates. Explicit
positions/open flags; sinf is a float32 host-math stub, no UIKit framebuffer.
"""
from native_creep_reference import *
import math
class ModeProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0x85126:u.emu_stop();return
  if a==0x36c88c:
   value=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0];self.ret(BITS(math.sin(value)));return
  super().hook(u,a,size,data)
 def run(self,offset,opened,steps):
  self.u.mem_write(E,bytes(0x1000));self.point(E+0x54,(360,369));self.point(E+0x5c,offset);self.u.mem_write(E+0x74,I(opened))
  self.u.mem_write(E+0x6c,F(0));self.u.mem_write(E+0x80,F(0))
  frames=[]
  for dt in steps:
   self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
   for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,BITS(dt),0,0]):self.u.reg_write(r,v)
   self.u.mem_write(STACK-32,bytes(12));self.u.emu_start(0x84f29,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==0x85126
   vals={k:struct.unpack('<f',self.u.mem_read(E+off,4))[0] for k,off in [('x',0x64),('y',0x68),('phase',0x6c),('geometry_alpha',0x70),('flash_ms',0x7c),('text_phase',0x80),('text_alpha',0x84)]}
   frames.append({'dt_ms':dt,'state':vals})
  return frames
probe=ModeProbe();cases=[]
for offset in [(51,-224),(20,-151),(4,-78),(4,78),(20,151),(51,224)]:
 for opened in [False,True]:
  for steps in [[0,1,99,50,150,150,150], [16.667]*40]:cases.append({'offset':offset,'opened':opened,'frames':probe.run(offset,opened,steps)})
result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-mode-item-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
