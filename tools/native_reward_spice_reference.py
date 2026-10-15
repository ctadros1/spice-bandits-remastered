"""Original spice-row render branch0xba9aa..0xbacb8 with explicit text metadata.

The earlier format/service/font setup is omitted. Supplied content dimensions
and power-of-two quad dimensions are recorded at the original RenderText call;
text alpha is a recording stub and bursts are marked already emitted. No old
UIKit font raster, string formatting or whole result screen is executed.
"""
from native_creep_reference import *

class SpiceProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0xbacb8:u.emu_stop();return
  if a==0x12262c:
   self.alpha=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R1)))[0];self.ret();return
  if a==0x116c30:
   self.draw={'point':list(struct.unpack('<2f',I(u.reg_read(UC_ARM_REG_R1))+I(u.reg_read(UC_ARM_REG_R2)))),'quad':list(struct.unpack('<2f',u.mem_read(E+0x2014,8))),'alpha':self.alpha};self.ret();return
  super().hook(u,a,size,data)
 def run(self,content,quad,phase,alpha,root_alpha):
  self.u.mem_write(E,bytes(0x3000));self.draw=None;self.alpha=None
  self.u.mem_write(E+0x14,F(root_alpha));self.u.mem_write(E+0xe8,F(alpha));self.u.mem_write(E+0xec,struct.pack('<2i',188,127));self.u.mem_write(E+0xb8,b'\x01')
  self.u.mem_write(E+0x1008,I(E+0x2000));self.u.mem_write(E+0x2008,struct.pack('<2f',*content));self.u.mem_write(E+0x2014,struct.pack('<2f',*quad))
  self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.mem_write(STACK+0x40,I(E));self.u.mem_write(STACK+0x28,I(E+0x1000))
  self.u.reg_write(UC_ARM_REG_D9,struct.unpack('<Q',F(phase)*2)[0])
  self.u.emu_start(0xba9ab,0xbacb8,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==0xbacb8
  return {'content':content,'quad':quad,'phase':phase,'alpha':alpha,'root_alpha':root_alpha,'draw':self.draw,'quad_restored':list(struct.unpack('<2f',self.u.mem_read(E+0x2014,8)))==list(quad)}

def main():
 p=SpiceProbe();cases=[p.run(c,q,t,a,r) for c,q in [((160,20),(256,32)),((233.5,21),(256,32)),((257.25,31),(512,32)),((511,33),(512,64))] for t in [0,.01,.25,.5,.75,.999,1,1.5] for a,r in [(1,1),(.75,.5)]]
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-reward-spice-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
