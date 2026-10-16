"""R148 full original Creep.UpdateParticles owner-field/dispatch evidence.
Supplied creep health/state/smoke settings and two mapped particle roots;
attached smoke aliases the first mapped root. Full original UpdateParticles
executes; Particle.Update is a recording stub and map successor is supplied.
No constructor, particle physics/emission, SetDie, game/room/render/GPU runs.
"""
import sys,itertools
sys.path.insert(0,'tools')
from native_creep_death_reference import *

class OwnerParticles(Death):
 def __init__(self):
  super().__init__();rows=json.loads(Path('original/analysis/functions.json').read_text());row=next(x for x in rows if x['address']==0x7bce4);self.body=bytes(self.u.mem_read(0x7bce4,row['size']));self.heavy_address=struct.unpack('<I',self.u.mem_read(0x40a1e8,4))[0]
 def word(self,a):return struct.unpack('<I',self.u.mem_read(a,4))[0]
 def root_fields(self,p):
  return {'rate':self.word(p+4),'backup_rate':self.word(p+0xb0),'interval_bits':self.word(p+8),'rgb_bits':[self.word(p+x) for x in [0x38,0x3c,0x40]],'position_bits':[self.word(p+0xa0),self.word(p+0xa4)]}
 def hook(self,u,a,size,data):
  if a==0x111088:
   p=u.reg_read(UC_ARM_REG_R0);self.calls.append({'root':(p-E-0x6000)//0x200,'delta_seconds_bits':u.reg_read(UC_ARM_REG_R1),'fields':self.root_fields(p)});self.ret();return
  super().hook(u,a,size,data)
 def setup_owner(self,state,hp,smoke,enabled,heavy,moving,interval=.3,multiplier=3.5):
  self.setup_tail(state,None,[0,0],[]);u=self.u
  for off,value in [(0x140,hp),(0x2e8,.111),(0x2ec,interval),(0x2f0,multiplier)]:u.mem_write(E+off,F(value))
  u.mem_write(E+0x144,I(100));u.mem_write(E+0x2f4,I(7));u.mem_write(E+0x2f8,bytes([int(enabled)]));u.mem_write(self.heavy_address,bytes([int(heavy)]));u.mem_write(E+0x2c8,I(E+0x6000 if smoke else 0))
  self.point(E+0x190,(330.5,220.5));self.point(E+0x1a8,(.6,.8))
  for i,offset in enumerate([(3,4),(-6,8)]):
   p=E+0x6000+i*0x200;u.mem_write(p+4,I(37+i));u.mem_write(p+0xb0,I(11+i));u.mem_write(p+8,F(.3+i*.1));u.mem_write(p+0x38,struct.pack('<3f',.25,.5,.75));info=E+0x10000+i*0x100
   u.mem_write(p+0xfc,I(info));self.point(info+0xc,offset);u.mem_write(info+0x15,bytes([int(moving[i])]))
 def snapshot(self):
  return {'state':self.u.mem_read(E+0x170,1)[0],'smoke_work_interval_bits':self.word(E+0x2e8),'roots':[self.root_fields(E+0x6000+i*0x200) for i in range(2)]}
 def sample(self,inp):
  self.setup_owner(**{k:inp[k] for k in ['state','hp','smoke','enabled','heavy','moving','interval','multiplier']});self.calls=[];before=self.snapshot();self.invoke(0x7bce4,[E,BITS(inp['dt_ms']),inp['argument']]);after=self.snapshot()
  assert [c['root'] for c in self.calls]==[0,1]
  assert all(c['fields']==after['roots'][c['root']] for c in self.calls)
  assert bytes(self.u.mem_read(0x7bce4,len(self.body)))==self.body
  return {'input':inp,'before':before,'after':after,'calls':self.calls}
def main():
 p=OwnerParticles();cases=[]
 def add(**values):
  inp={'state':0,'hp':30,'smoke':True,'enabled':True,'heavy':False,'moving':[False,False],'interval':.3,'multiplier':3.5,'dt_ms':30,'argument':0};inp.update(values);cases.append(p.sample(inp))
 # Supplied smoking flag/raw state and exact float32 threshold/clamp inputs.
 for state,hp,enabled,interval in itertools.product(range(8),[-1,0,30,60,60.000003814697266,60.00000762939453,100],[False,True],[.001,.3,1.0]):add(state=state,hp=hp,enabled=enabled,interval=interval)
 # Moving-only/heavy flags, both mapped roots, ms->seconds and bool argument.
 for state,heavy,moving,argument,dt in itertools.product(range(8),[False,True],[[False,False],[True,False],[False,True],[True,True]],[0,1],[0,30,133.333]):add(state=state,smoke=False,heavy=heavy,moving=moving,argument=argument,dt_ms=dt)
 # No constructor or DoOnDying is inserted between these supplied calls.
 sequences=[]
 for moving in [[False,False],[True,False]]:
  p.setup_owner(0,30,True,True,False,moving);frames=[]
  for state,hp,enabled,heavy in [(0,30,1,0),(0,30,0,0),(2,0,1,0),(3,0,1,0),(0,60,1,0),(0,30,1,1),(0,30,1,0)]:
   p.u.mem_write(E+0x170,bytes([state]));p.u.mem_write(E+0x140,F(hp));p.u.mem_write(E+0x2f8,bytes([enabled]));p.u.mem_write(p.heavy_address,bytes([heavy]));before=p.snapshot();p.calls=[];p.invoke(0x7bce4,[E,BITS(30),0]);frames.append({'input':dict(state=state,hp=hp,enabled=enabled,heavy=heavy,dt_ms=30),'before':before,'after':p.snapshot(),'calls':p.calls.copy()});assert [c['root'] for c in p.calls]==[0,1]
  sequences.append({'moving':moving,'frames':frames})
 assert bytes(p.u.mem_read(0x7bce4,len(p.body)))==p.body and hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_catalog_body_bytes':len(p.body),'original_file_and_full_function_unchanged':True,'attached_smoke_pointer_is_mapped_root_alias':True,'cases':cases,'sequences':sequences}
 Path('tests/fixtures/native-creep-particle-owner-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sequences':len(sequences),'calls':sum(len(c['calls']) for c in cases)+sum(len(f['calls']) for s in sequences for f in s['frames']),'function_bytes':len(p.body),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
