"""Original CCreepManager air-pass routing over supplied creep vectors.

Runs full0xfbe8c with supplied vector/object/resource/vtable records. OpenGL
color/blend calls and virtual before/body/after methods are recording stubs.
No actual creep drawing, GPU, lifespan, concurrency or whole room runs.
"""
from native_map_order_reference import *


class AirProbe(OrderProbe):
 def reset(self,stop=END):
  super().reset(stop);self.calls=[]
 def hook(self,u,a,size,data):
  if a in [END+0x100,END+0x120,END+0x140]:
   actor=u.reg_read(UC_ARM_REG_R0);label=(actor-E-0x10000)//0x400
   self.calls.append({'pass':{END+0x100:'before',END+0x120:'body',END+0x140:'after'}[a],'label':label})
   self.ret();return
  if a in [0x36b2ac,0x11515c]:self.ret();return
  super().hook(u,a,size,data)
 def route(self,types):
  self.reset();self.u.mem_write(E+0x10000,bytes(0x60000))
  start=E+0x7000
  self.u.mem_write(0x47ed54,struct.pack('<3I',start,start+4*len(types),start+4096))
  for i,kind in enumerate(types):
   actor=E+0x10000+i*0x400;resource=E+0x60000+i*0x20;vtable=E+0x50000+i*0x40
   self.u.mem_write(start+4*i,I(actor));self.u.mem_write(actor,I(vtable));self.u.mem_write(actor+0x250,I(resource));self.u.mem_write(resource+4,I(kind))
   self.u.mem_write(vtable,struct.pack('<4I',0,END+0x121,END+0x101,END+0x141))
  self.invoke(0xfbe8c,[])
  return self.calls


def main():
 p=AirProbe();cases=[]
 for types in [[],[1],[2],[1,2,1,2],[2,1,2],[2,2,2],[0,1,2,3],[1,1,1]]:
  cases.append({'types':types,'output':p.route(types)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-air-pass-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'calls':sum(len(x['output']) for x in cases),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
