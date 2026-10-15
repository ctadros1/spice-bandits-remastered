"""Original CBolt full Render and CTower RenderAfter bolt-call ordering.

Explicit object buffers replace game construction/ownership; all GL, texture,
quad and subordinate effect calls are recording stubs. Original ARM branches
and vector iteration execute. No original GPU, map sorting or game execution.
"""
from native_bolt_appearance_reference import AppearanceProbe
from native_creep_reference import *

class OrderProbe(AppearanceProbe):
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==0xddce8 and self.owner_mode:
   self.calls.append({'bolt':r0-E});self.ret();return
  if a in [0x36b1ac,0x36b3cc,0x36b55c,0x36b60c,0x36b3dc,0x36b29c,0x36b5cc,0x36b3ac,0x36b54c,0x11512c,0x11520c]:
   self.ret();return
  if a==0x36b63c:self.buffer=r3;self.ret();return
  if a==0x36b3bc:self.calls.append({'draw':{'mode':r0,'first':r1,'count':r2,'buffer':self.buffer-E}});self.ret();return
  if a==0x36b2cc:self.ret();return
  super().hook(u,a,size,data)
 def render_all(self,alive,ball,alpha):
  self.reset();self.owner_mode=False;self.buffer=0
  self.u.mem_write(E+0x54,bytes([int(alive)]));self.u.mem_write(E+0x48,F(alpha))
  self.u.mem_write(E+0x68,I(E+0x4000 if ball else 0));self.u.mem_write(E+0x4008,struct.pack('<2i',64,64))
  self.point(E+0x60,[32,32]);self.u.mem_write(E+0x30,struct.pack('<4I',E+0x5000,24,E+0x6000,26))
  self.invoke(0xddce8,[E]);return {'alive':alive,'ball':ball,'alpha':alpha,'calls':self.calls}
 def owner(self,visible,primary,bolts):
  self.reset();self.owner_mode=True
  self.u.mem_write(E+0x40,bytes([int(visible)]));self.u.mem_write(E+0x20c,I(E+0x1000 if primary else 0))
  self.u.mem_write(E+0x1e8,struct.pack('<2I',E+0x3000,E+0x3000+len(bolts)*4))
  for i,offset in enumerate(bolts):self.u.mem_write(E+0x3000+i*4,I(E+offset))
  self.invoke(0xe8028,[E]);return {'visible':visible,'primary':primary,'bolts':bolts,'calls':self.calls}

def main():
 p=OrderProbe();p.owner_mode=False
 renders=[p.render_all(a,b,c) for a in [False,True] for b in [False,True] for c in [0,.35,1]]
 owners=[p.owner(v,s,b) for v in [False,True] for s in [False,True] for b in [[],[0x1400],[0x1800,0x1400,0x1c00]]]
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'renders':renders,'owners':owners,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-bolt-order-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'renders':len(renders),'owners':len(owners),'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
