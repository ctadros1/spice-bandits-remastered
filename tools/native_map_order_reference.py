"""Execute original CMap full sorting/registration against supplied vectors.

Uses the preserved1.14 ARM code, comparator and linked sort templates. Map,
object fields and reserved vector storage are supplied; no constructor,
rendering, concurrency or whole game runs. memmove and thread lock/unlock
are explicit stubs. Inputs stay within reserved capacities; allocation is
not modeled. Repeated sorting captures original equal-depth permutations.
"""
from native_map_depth_reference import *
import random


class OrderProbe(DepthProbe):
 def reset(self,stop=END):
  super().reset(stop);self.thread_calls=[]
 def hook(self,u,a,size,data):
  if a==0x36c6bc:
   destination=u.reg_read(UC_ARM_REG_R0);source=u.reg_read(UC_ARM_REG_R1);count=u.reg_read(UC_ARM_REG_R2)
   if count:u.mem_write(destination,bytes(u.mem_read(source,count)))
   self.ret(destination);return
  if a in [0x10da10,0x10da1c]:self.thread_calls.append('lock' if a==0x10da10 else 'unlock');self.ret();return
  super().hook(u,a,size,data)
 def invoke(self,address,args):
  self.u.reg_write(UC_ARM_REG_SP,STACK-0x1000);self.u.reg_write(UC_ARM_REG_LR,self.stop|1)
  for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(reg,value)
  try:self.u.emu_start(address|1,self.stop,count=2_000_000)
  except UcError as error:raise RuntimeError(f'{error}; method={hex(address)}, PC={hex(self.u.reg_read(UC_ARM_REG_PC))}') from error
  assert self.u.reg_read(UC_ARM_REG_PC)==self.stop,hex(self.u.reg_read(UC_ARM_REG_PC))
 def object(self,label):return E+0x10000+label*0x40
 def setup(self,values,main,pending=(),locked=False,counter=0):
  self.reset();self.u.mem_write(E+0x10000,bytes(0x10000))
  for label,value in enumerate(values):
   address=self.object(label);self.u.mem_write(address+4,I(label));self.u.mem_write(address+0xc,struct.pack('<i',value[0]));self.u.mem_write(address+0x14,F(value[1]))
  for offset,start,labels in [(0x50,E+0x8000,main),(0x5c,E+0xc000,pending)]:
   self.u.mem_write(E+offset,struct.pack('<3I',start,start+4*len(labels),start+4096))
   if labels:self.u.mem_write(start,struct.pack('<'+'I'*len(labels),*[self.object(i) for i in labels]))
  self.u.mem_write(E+0x4c,bytes([int(locked),0]));self.u.mem_write(E+0xa8,I(counter))
 def state(self):
  output={}
  for key,offset in [('main',0x50),('pending',0x5c)]:
   start,end=struct.unpack('<2I',self.u.mem_read(E+offset,8));pointers=struct.unpack('<'+'I'*((end-start)//4),self.u.mem_read(start,end-start)) if end>start else []
   output[key]=[(p-E-0x10000)//0x40 for p in pointers]
   output[key+'_ids']=[struct.unpack('<I',self.u.mem_read(p+4,4))[0] for p in pointers]
  output['counter']=struct.unpack('<I',self.u.mem_read(E+0xa8,4))[0]
  output['flags']=list(self.u.mem_read(E+0x4c,2));output['thread_calls']=list(self.thread_calls)
  return output
 def sorts(self,values,locked=False):
  self.setup(values,list(range(len(values))),locked=locked)
  result=[]
  for _ in range(3):self.invoke(0x103684,[E]);result.append(self.state())
  return result
 def registration(self,main,pending,locked,actions):
  self.setup([[0,0]]*20,main,pending,locked,100)
  result=[]
  for action in actions:
   if action['kind']=='unlock':self.u.mem_write(E+0x4c,b'\0')
   elif action['kind']=='register':self.invoke(0x1034c0,[E,self.object(action['label'])])
   result.append(self.state())
  return result


def main():
 p=OrderProbe();sorts=[];r=random.Random(114)
 for size in [0,1,2,3,7,15,16,17,18,31,32,33,64,65,128]:
  patterns={'ascending':[[i,0] for i in range(size)],'descending':[[size-i,0] for i in range(size)],'equal':[[100,25] for _ in range(size)],'repeated':[[i%5,0] for i in range(size)],'fractional':[[r.randrange(-100,101),r.randrange(-10,11)*0.125] for _ in range(size)],'f32-collisions':[[16777216+i%3,0] for i in range(size)]}
  for name,values in patterns.items():
   for locked in [False,True]:sorts.append({'pattern':name,'size':size,'locked':locked,'values':values,'output':p.sorts(values,locked)})
 registrations=[]
 for main_ids,pending,locked,actions in [([],[],False,[{'kind':'register','label':0},{'kind':'register','label':1}]),([2,0,1],[],False,[{'kind':'register','label':3}]),([0,1,2],[],True,[{'kind':'register','label':3},{'kind':'unlock'},{'kind':'register','label':4}]),([1,0],[2,3],False,[{'kind':'register','label':4}])]:
  registrations.append({'main':main_ids,'pending':pending,'locked':locked,'actions':actions,'output':p.registration(main_ids,pending,locked,actions)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'sorts':sorts,'registrations':registrations,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-map-order-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'sort_cases':len(sorts),'registration_cases':len(registrations),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
