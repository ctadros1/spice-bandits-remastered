"""Original page/interface fade with explicit requests and a stub page swap.

The original Update methods execute. End-condition callback and SwitchPage
allocation/UI initialization are stubs; this records fade arithmetic/order.
"""
from native_creep_reference import *
PAGE=E+0x100;CALLBACK=END-0x1000
class TutorialProbe(Probe):
 def hook(self,u,a,size,data):
  if a==CALLBACK:
   if self.request:self.u.mem_write(E+0xc,b'\x01');self.request=False
   self.ret(0);return
  if a==0xb31c8:
   self.switched=True;self.reset_page();self.ret(0);return
  super().hook(u,a,size,data)
 def reset_page(self):
  self.u.mem_write(PAGE,bytes(0x38));self.u.mem_write(PAGE+0x34,I(CALLBACK|1));self.u.mem_write(E+4,I(PAGE))
 def run(self,steps):
  self.u.mem_write(E,bytes(0x200));self.reset_page();frames=[]
  for dt,request in steps:
   self.request=request;self.switched=False
   self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
   self.u.mem_write(STACK-32,bytes(12))
   for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,BITS(dt),0,0]):self.u.reg_write(r,v)
   self.u.emu_start(0xb7c99,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
   frames.append({'dt_ms':dt,'request':request,'state':{'alpha':struct.unpack('<f',self.u.mem_read(PAGE+0x24,4))[0],'previous_ms':struct.unpack('<f',self.u.mem_read(PAGE+0x2c,4))[0],'opaque':bool(self.u.mem_read(PAGE+0x30,1)[0])},'pending':bool(self.u.mem_read(E+0xc,1)[0]),'switched':self.switched})
  return frames
probe=TutorialProbe();cases=[]
for steps in [[(0,False),(100,False),(100,False),(200,False),(0,False),(100,True),(150,False),(150,False),(100,False)],[(16.667,False)]*32+[(16.667,True)]+[(16.667,False)]*32,[(100,True),(100,False),(0,False),(500,False),(50,True),(500,False)],[(500,False),(500,False),(500,True),(0,False),(500,False)]]:cases.append({'frames':probe.run(steps)})
result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-tutorial-fade-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
