"""R192 bounded full original CPoison C2/Update/UpdateParticles chronology.

Full selected bodies execute unchanged on supplied resource/actor/global-vector
and parent records, with reserved vector capacity. Particle factory/Update/
destructor are explicit recording/status stubs, not original particle physics;
Update stub counts are a supplied finite-tail model. Random/vector, decals,
sound, delete, exception registration, ldexpf/memmove are explicit callbacks.
No resource parser, real parent production, cloud particle trajectory/render,
actual damage/death/reward, room/tower manager or whole game runs. Original
files/instruction bytes remain unchanged. Captures caller clocks, requests,
header mutations, before-update deletion/compaction, parent gating and tails.
"""
from pathlib import Path
import sys,json,struct,math,argparse,itertools,hashlib
sys.path.insert(0,'tools')
from native_creep_poison_callers_reference import *
def f32(v):return struct.unpack('<f',F(v))[0]
class Lifecycle(PoisonProbe):
 def __init__(self):
  self.ps={};self.serial=0;self.tail_ms=2000;self.stub_frames=None;self.stub_call=0;self.random_value=0;self.vector_value=(1,0)
  super().__init__();catalog=json.loads(Path('original/analysis/functions.json').read_text())
  for a in [0xe0eb4,0xe1268,0xe194c,0x81bb0]:self.bodies[a]=bytes(self.u.mem_read(a,next(r['size'] for r in catalog if r['address']==a)))
 def node(self,p):return self.ps[p]['id'] if p in self.ps else None
 def root(self,name='supplied'):
  self.serial+=1;p=E+0x90000+self.serial*0x200;assert p<E+0xe0000;self.u.mem_write(p,bytes(0x200));self.ps[p]={'id':self.serial,'name':name,'updates':0}
  for off,val in [(4,3),(8,BITS(.08)),(0x44,BITS(1)),(0x50,BITS(1)),(0xa0,BITS(2.5)),(0xa4,BITS(7.5))]:self.u.mem_write(p+off,I(val))
  self.u.mem_write(p+0xd6,b'\x01');return p
 def hook(self,u,a,size,data):
  r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1)
  if a in [0x36ca5c,0x36ca7c]:self.ret();return
  if a in [0x36c7cc,0x36c7dc]:self.events.append({'kind':'random_stub','address':hex(a),'value':self.random_value});self.ret(self.random_value);return
  if a==0x36cadc:
   result=r0%r1 if r1 else 0;self.events.append({'kind':'signed_mod_stub','left':r0,'right':r1,'result':result});self.ret(result);return
  if a==0x110ab4:self.point(r0,self.vector_value);self.events.append({'kind':'vector_stub','bits':[BITS(v) for v in self.vector_value]});self.ret();return
  if a==0x111834:
   name=self.string(r0);p=self.root(name);self.events.append({'kind':'factory_stub','id':self.node(p),'name':name});self.ret(p);return
  if a==0x111088:
   n=self.ps[r0];n['updates']+=1;dt=struct.unpack('<f',I(r1))[0];clock=f32(struct.unpack('<f',u.mem_read(r0+0xc0,4))[0]+dt);u.mem_write(r0+0xc0,F(clock));u.mem_write(r0+0xd6,b'\0')
   if self.stub_frames is not None:active=self.stub_frames[min(n['updates']-1,len(self.stub_frames)-1)]
   else:
    disable=struct.unpack('<f',u.mem_read(r0+0x4c,4))[0];active=2 if clock<f32(disable+self.tail_ms/1000.0) else 0
   u.mem_write(r0+0xb8,struct.pack('<i',active));self.events.append({'kind':'particle_update_stub','id':n['id'],'dt_seconds_bits':r1,'active_after':active,'stub_clock_bits':BITS(clock)});self.ret();return
  if a==0x110f0c:self.events.append({'kind':'particle_destructor_stub','id':self.node(r0)});self.ret();return
  if a==0x36c18c:self.events.append({'kind':'delete_stub','id':self.node(r0)});self.ret();return
  if a==0xe11dc:self.events.append({'kind':'AddDecals_stub'});self.ret();return
  if a==0x1205dc:self.events.append({'kind':'sound_stub','name':self.string(r0),'position_bits':[self.word(r1),self.word(r1+4)],'argument':u.reg_read(UC_ARM_REG_R2)});self.ret();return
  if a==0x1177e0:self.events.append({'kind':'texture_stub','name':self.string(r1),'result':None});self.ret(0);return
  super().hook(u,a,size,data)
 def state(self):
  p=E;u=self.u;res=self.word(p);start,end=struct.unpack('<2I',u.mem_read(p+0x34,8));assert end>=start and end-start<=512
  roots=[]
  for at in range(start,end,4):
   q=self.word(at);n=self.ps[q];roots.append({'id':n['id'],'name':n['name'],'rate':self.word(q+4),'interval_bits':self.word(q+8),'disable_after_bits':self.word(q+0x4c),'position_bits':[self.word(q+0xa0),self.word(q+0xa4)],'alpha_bits':self.word(q+0x44),'active_count':struct.unpack('<i',u.mem_read(q+0xb8,4))[0],'first_release':u.mem_read(q+0xd6,1)[0],'stub_update_calls':n['updates'],'stub_clock_bits':self.word(q+0xc0)})
  return {'active':u.mem_read(p+0x18,1)[0],'deleted':u.mem_read(p+0x19,1)[0],'age_ms_bits':self.word(p+4),'emit_age_ms_bits':self.word(p+0x1c),'position_bits':[self.word(p+8),self.word(p+12)],'initial_position_bits':[self.word(p+0x10),self.word(p+0x14)],'bonus_bits':self.word(p+0x20),'owner':self.word(p+0x24),'radiation':u.mem_read(p+0x28,1)[0],'parent30_present':bool(self.word(p+0x30)),'parent40_present':bool(self.word(p+0x40)),'ready44':u.mem_read(p+0x44,1)[0],'roots':roots,'creeps':super().snapshot(),'events':self.events.copy()}
 def setup(self,radiation=0,slow=0,word8=2,duration=200,tail_ms=2000,parent='none'):
  actors=[{'pos':[100,150],'initial_rate':7},{'pos':[500,500],'initial_rate':7},{'pos':[100,150],'resource_kind':2,'initial_rate':7}]
  self.setup_clouds(actors,[{'pos':[100,150],'radiation':radiation}]);self.ps={};self.serial=0;self.tail_ms=tail_ms;self.stub_frames=None;self.random_value=0;self.vector_value=(1,0)
  d=E+0x8000;self.u.mem_write(d+8,I(word8));self.u.mem_write(d+0x5c,F(duration));self.u.mem_write(d+0x8a,bytes([slow]));self.point(E+0x6000,(100,150))
  self.u.mem_write(STACK-0x1000,F(2.5)+I(radiation));self.events=[];self.invoke(0xe0eb4,[E,d,43,E+0x6000]);ctor=self.state()
  for off,start in [(0x34,E+0xb000),(0x48,E+0xa000)]:self.u.mem_write(E+off,struct.pack('<3I',start,start,start+512))
  if parent=='parent30_active':self.u.mem_write(E+0x30,I(E+0x7000));self.u.mem_write(E+0x7044,b'\x01')
  elif parent=='parent40_zero':self.u.mem_write(E+0x40,I(E+0x7100));self.u.mem_write(E+0x7104,I(0))
  return ctor
 def sequence(self,inp):
  ctor=self.setup(**{k:v for k,v in inp.items() if k!="deltas"});frames=[];after_damage_end=False
  for frame in range(120):
   self.events=[]
   if frame==3 and inp['parent']!='none':
    if inp['parent']=='parent30_active':self.u.mem_write(E+0x7044,b'\0')
    else:self.u.mem_write(E+0x7104,I(1))
   # Explicit per-frame supplied fields, not an executed owner/room pass.
   for p in self.actors:
    self.u.mem_write(p+0x218,I(0));self.u.mem_write(p+0x21c,I(0));self.u.mem_write(p+0x230,F(-1))
   dt=inp.get("deltas",[30])[frame%len(inp.get("deltas",[30]))];self.invoke(0xe1268,[E,BITS(dt),0]);state=self.state();state['frame']=frame;frames.append(state)
   if not state['active']:break
  assert not frames[-1]['active'],'supplied finite particle-tail callback must terminate'
  return {'input':inp,'constructor':ctor,'frames':frames}
 def direct_particles(self,records,dt):
  self.setup(duration=200);self.events=[];self.stub_frames=[0];start=E+0xb000
  for i,r in enumerate(records):
   p=self.root();self.u.mem_write(p+0xb8,struct.pack('<i',r['active']));self.u.mem_write(p+0xd6,bytes([r['first']]));self.u.mem_write(p+0x4c,F(r['disable']));self.u.mem_write(start+4*i,I(p))
  self.u.mem_write(E+0x38,I(start+4*len(records)));before=self.state();frames=[]
  for _ in range(2):self.events=[];self.invoke(0xe194c,[E,BITS(dt)]);frames.append(self.state())
  return {'input':{'roots':records,'dt_ms':dt,'particle_update_stub_active_after':0},'before':before,'frames':frames}
 def header_case(self,rad,slow,word8,height,radius,duration,random_value,vector):
  ctor=self.setup(radiation=rad,slow=slow,word8=word8,duration=duration,tail_ms=2000)
  self.u.mem_write(E+0x4000,F(height));self.u.mem_write(E+0x8000+0x58,F(radius));self.random_value=random_value;self.vector_value=vector;self.events=[]
  self.invoke(0xe1268,[E,BITS(0),0]);return {'input':{'radiation':rad,'slow':slow,'word8':word8,'height':height,'radius':radius,'duration_ms':duration,'random_value':random_value,'vector':list(vector),'dt_ms':0},'after':self.state()}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);args=ap.parse_args();out=Path(args.output);assert not out.exists();p=Lifecycle();seq=[]
 for rad,slow,word8,tail,parent in itertools.product([0,1],[0,1],[1,2],[0,2000],['none','parent30_active','parent40_zero']):seq.append(p.sequence({'radiation':rad,'slow':slow,'word8':word8,'duration':200,'tail_ms':tail,'parent':parent}))
 seq.append(p.sequence({'radiation':0,'slow':0,'word8':2,'duration':0,'tail_ms':0,'parent':'none'}))
 for rad,slow,parent,deltas in itertools.product([0,1],[0,1],['none','parent30_active'],[[0,.001,16.667,30,100,133.333],[79.999,.001,.00001,100],[59.999,.001,.0001,66.667]]):seq.append(p.sequence({'radiation':rad,'slow':slow,'word8':2,'duration':200,'tail_ms':2000,'parent':parent,'deltas':deltas}))
 direct=[]
 for active,first,disable,dt in itertools.product([-1,0,2],[0,1],[0,100],[0,.001,16.667,30,133.333]):direct.append(p.direct_particles([{'active':active,'first':first,'disable':disable}],dt))
 direct.append(p.direct_particles([{'active':0,'first':0,'disable':100},{'active':2,'first':0,'disable':100},{'active':0,'first':0,'disable':0}],30))
 headers=[]
 for flags,height,radius,duration,rng,vec in itertools.product([(0,0,1),(0,0,2),(0,1,1),(0,1,2),(1,0,2)],[32,48],[0,1.5,2.5],[200,6000],[0,1,3,9,2147483647],[(1,0),(0,1),(.6,.8)]):headers.append(p.header_case(*flags,height,radius,duration,rng,vec))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 report={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_selected_bodies_unchanged':True,'bodies':{hex(a):{'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for a,b in p.bodies.items()},'counter_pending_reset_per_frame_supplied_not_executed_owner':True,'random_stub_value':0,'vector_stub':[1,0],'particle_factory_stub_header':{'rate':3,'interval':.08,'initial_position':[2.5,7.5],'alpha':1,'first_release':True},'sequences':seq,'direct_particles':direct,'emission_headers':headers,'header_disable_after_units':'seconds; CPoison writes f32(duration_ms*f32(.001))','verified_import_callbacks':{'0x36c62c':'ldexpf','0x36c7cc':'rand','0x36c7dc':'random','0x36cadc':'signed integer modsi3'}}
 out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'sequences':len(seq),'frames':sum(len(s['frames']) for s in seq),'particle_cases':len(direct),'emission_header_cases':len(headers),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}))
if __name__=='__main__':main()
