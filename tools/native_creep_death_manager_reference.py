"""Original complete CCreepManager.UpdateAllCreeps on supplied vectors.
Virtual destructor and ResetEffectCounters are recording stubs. Creep.Update
is explicitly substituted with full original DoOnDying (not full Update).
Its SetState hover is stubbed. No constructor/destructor/particle simulation,
SetDie/rewards/services/GPU or whole game executes. Tracks removal chronology.
"""
import sys,itertools,json
sys.path.insert(0,'tools')
from native_creep_death_reference import *
class Manager(Death):
 def hook(self,u,a,size,data):
  if a==END+0x200:self.removed.append((u.reg_read(UC_ARM_REG_R0)-E-0x1000)//0x1000);self.ret();return
  if a==0x7a8f8:self.reset_calls.append((u.reg_read(UC_ARM_REG_R0)-E-0x1000)//0x1000);self.ret();return
  if a==0x7e8d0:
   self.update_calls.append((u.reg_read(UC_ARM_REG_R0)-E-0x1000)//0x1000);u.reg_write(UC_ARM_REG_PC,0x7beb9);return
  super().hook(u,a,size,data)
 def setup_manager(self,states):
  self.reset();self.next_nodes={};self.updated=[];self.deleted=[];self.state_calls=[];self.removed=[];self.reset_calls=[];self.update_calls=[]
  u=self.u;start=E+0x70000
  u.mem_write(0x47ed54,struct.pack('<3I',start,start+4*len(states),start+256));u.mem_write(0x47ed60,b'\x01');u.mem_write(0x47ec48,I(37))
  vt=E+0x50000;u.mem_write(vt+0x24,I((END+0x200)|1))
  for i,state in enumerate(states):
   obj=E+0x1000+i*0x1000;u.mem_write(obj,bytes(0x400));u.mem_write(obj,I(vt));u.mem_write(obj+0x170,bytes([state]));u.mem_write(start+4*i,I(obj))
 def step_manager(self,dt):
  self.removed=[];self.reset_calls=[];self.update_calls=[];self.state_calls=[]
  self.invoke(0xfbf10,[BITS(dt),0])
  u=self.u;start,end=struct.unpack('<2I',u.mem_read(0x47ed54,8));ptrs=struct.unpack('<'+'I'*((end-start)//4),u.mem_read(start,end-start)) if end>start else []
  return {'actors':[{'label':(p-E-0x1000)//0x1000,'state':u.mem_read(p+0x170,1)[0]} for p in ptrs],'removed':list(self.removed),'reset':list(self.reset_calls),'updated':list(self.update_calls),'radiation':u.mem_read(0x47ed60,1)[0],'renderable_count':struct.unpack('<I',u.mem_read(0x47ec48,4))[0]}
def main():
 p=Manager();cases=[]
 for states in [[],[2],[3],[0],[2,2],[3,3],[0,2,3],[2,0,2,3,2],[3,0,3,2],[2,2,0,3,2,2]]:
  p.setup_manager(states);cases.append({'states':states,'frames':[p.step_manager(30) for _ in range(3)]})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases}
 Path('tests/fixtures/native-creep-death-manager-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps(data))

if __name__=="__main__":main()
