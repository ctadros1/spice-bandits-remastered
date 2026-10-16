"""Full original SetDie on supplied empty particle/texture/sound resources.
SetState executes with hover stub; tower/portal cleanup are recording stubs.
GetParam/texture/system lookup returns null; GetParticlesList returns a
supplied empty tree, so resource-driven effects/sound/RNG are not exercised.
Existing particle-tree successor is explicit. No full combat/death/resource
construction, allocation, services, rendering or original game executes.
"""
import sys,itertools,json
sys.path.insert(0,'tools')
from native_creep_death_reference import *
class SetDie(Death):
 def hook(self,u,a,size,data):
  r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1)
  if a in [0x9cec8,0xe9a74]:self.events.append({'method':'portal-clean' if a==0x9cec8 else 'tower-clean','owner':r0==E});self.ret();return
  if a==0x11794c:self.events.append({'method':'param','name':self.string(r1)});self.ret(0);return
  if a==0x1177e0:self.events.append({'method':'texture','name':self.string(r1)});self.ret(0);return
  if a==0x117940:self.events.append({'method':'particle-list'});self.ret(E+0x3000);return
  super().hook(u,a,size,data)
 def run_death(self,state,kind,already,resource,counts):
  self.setup_tail(state,None,counts,[]);u=self.u;self.events=[];u.mem_write(E+0x250,I(E+0x1000));u.mem_write(E+0x104c,I(E+0x2000 if resource else 0));u.mem_write(E+0x320,bytes([already]))
  for i in range(len(counts)):u.mem_write(E+0x6000+i*0x200+4,I(37))
  self.invoke(0x7a150,[E,kind])
  return {'state':u.mem_read(E+0x170,1)[0],'previous_state':u.mem_read(E+0x173,1)[0],'crater_created':u.mem_read(E+0x320,1)[0],'emission_rates':[struct.unpack('<I',u.mem_read(E+0x6000+i*0x200+4,4))[0] for i in range(len(counts))],'state_calls':self.state_calls,'events':self.events}
def main():
 p=SetDie();cases=[]
 for state,kind,already,resource,counts in itertools.product(range(8),range(5),[False,True],[False,True],[[],[0],[1],[0,1]]):
  out=p.run_death(state,kind,already,resource,counts);assert out['state']==3 and out['previous_state']==state and out['crater_created']==(already or resource) and out['emission_rates']==[0]*len(counts)
  cases.append({'input':dict(state=state,kind=kind,already=already,resource=resource,particle_counts=counts),'output':out})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases}
 Path('tests/fixtures/native-creep-death-setdie-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'source_unchanged':data['original_unchanged'],'example':cases[0]}))

if __name__=="__main__":main()
