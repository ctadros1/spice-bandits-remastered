"""R149 full Creep.C2 + actual particle factory/C2 on supplied records.
Authored creep parameters/bindings and explicitly supplied particle header
fields used by the creep constructor. Other header bytes are zero. Resource,
map/string/new/texture/random/non-particle callbacks are explicit stubs.
Full original SetState runs with its hover helper stubbed.
No resource parser, original registry/game/room/render/GPU execution.
"""
import sys,json,struct,hashlib
from collections import deque
sys.path.insert(0,'tools')
from native_particle_factory_reference import *

class Constructor(FactoryProbe):
 def __init__(self):
  self.trace=deque(maxlen=80);super().__init__();self.animations=json.loads(Path('game/data/animations.json').read_text());self.particles=json.loads(Path('game/data/particles.json').read_text());self.catalog=json.loads(Path('original/analysis/functions.json').read_text());self.bodies={a:bytes(self.u.mem_read(a,next(r['size'] for r in self.catalog if r['address']==a))) for a in [0x78374,0x113d9c,0x110e20,0x798ec]}
 def alloc(self,size):
  at=self.heap;self.heap+=max(0x100,((size+0xff)//0x100)*0x100);self.u.mem_write(at,bytes(max(0x100,size)));return at
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]];self.trace.append({'pc':hex(a),'r0':hex(r0),'r1':hex(r1),'r2':hex(r2),'lr':hex(u.reg_read(UC_ARM_REG_LR))})
  if a==self.stop:u.emu_stop();return
  if a==0x113d9c:
   self.pending=self.string(r0);self.factory_inputs.append({'name':self.pending,'info':r1});return
  if a==0x114140:self.ret(E+0x30000 if self.pending in self.records else 0x47eddc);return
  if a==0x114030:
   u.mem_write(E+0x30004,I(self.records[self.pending]));self.ret(E+0x30004);return
  if a==0x36c1bc:self.ret(self.alloc(r0));return
  if a==0x36c6cc:u.mem_write(r0,bytes([r1&255])*r2);self.ret(r0);return
  if a==0x36c6ac:u.mem_write(r0,bytes(u.mem_read(r1,r2)));self.ret(r0);return
  if a in [0x36c04c]:u.mem_write(r0,I(r1));self.ret(r0);return
  if a in [0x36c01c,0x36c05c]:u.mem_write(r0,bytes(u.mem_read(r1,4)));self.ret(r0);return
  if a in [0x36c06c,0x36ca5c,0x36ca7c]:self.ret();return
  if a==0x36c7cc:self.ret(0);return
  if a==0x36cadc:self.ret(r0%r1 if r1 else 0);return
  if a==0x36c9dc:
   source=self.string(r0);needle=self.string(r1);i=source.find(needle);self.ret(r0+i if i>=0 else 0);return
  if a==0x11794c:
   key=self.string(r1);self.param_calls.append(key);self.ret(self.params.get(key,0));return
  if a==0x117940:self.ret(E+0x5000);return
  if a==0x36c11c:self.ret(self.next_nodes[r0]);return
  if a==0x77294:
   alias=self.string(self.word(r1));node=E+0x40000+len(self.slots)*0x40;self.slots[alias]=node;u.mem_write(node+0x10,I(self.word(r1)));u.mem_write(E+0x278,I(len(self.slots)));self.ret(node+0x14);return
  if a==0x773b0:
   alias=self.string(self.word(r1));self.ret(self.slots.get(alias,E+0x268));return
  if a==0x771b4:self.ret(E+0x50000);return
  if a==0x1177e0:self.ret(0);return
  if a==0x1262cc:self.ret(1);return
  if a==0x798ec:return # Execute full original SetState; hover helper is stubbed.
  if a==0x110b5c:self.point(r0,(0,0));self.ret();return
  if a in [0x10a2c4,0x10ef20,0x10ef7c,0x10f0cc,0xfc648,0x9ec84,0x9e768,0x1034c0,0x81fa4,0x81cd4,0x7f95c,0x7995c,0x7e870]:self.nonparticle.append(hex(a));self.ret(0);return
  if a==0x118690:self.ret(E+0x4000);return
  if a==0x111418:raise RuntimeError('Unexpected Emit in constructor chain')
  if a==0x36c33c:raise RuntimeError('stack guard failed')
  # Deliberately execute other original instructions; unknown calls fail with trace.
 def sample(self,name,map_field8=1,resource_kind=1):
  u=self.u;self.heap=E+0x60000;u.mem_write(E,bytes(0x90000));self.params={};self.next_nodes={};self.slots={};self.records={};self.factory_inputs=[];self.param_calls=[];self.nonparticle=[];self.pending='';self.stop=END;self.homogeneous=True
  resource=self.animations[name]
  for i,(key,value) in enumerate(resource['params'].items()):
   p=E+0x10000+i*0x100;self.params[key]=p
   if isinstance(value,(bool,int,float)):
    u.mem_write(p+4,I(int(value)&0xffffffff));u.mem_write(p+8,I(int(value)&0xffffffff));u.mem_write(p+0xc,F(value))
   elif isinstance(value,list) and len(value)==2 and all(isinstance(x,(int,float)) for x in value):self.point(p+0x14,value)
  bindings=self.particles['bindings'][name];end=E+0x5004;u.mem_write(E+0x5014,I(len(bindings)));u.mem_write(E+0x500c,I(E+0x6000))
  for i,(alias,b) in enumerate(sorted(bindings.items())):
   node=E+0x6000+i*0x40;info=E+0x8000+i*0x40;self.next_nodes[node]=node+0x40 if i+1<len(bindings) else end;u.mem_write(node+0x10,struct.pack('<2I',self.intern(alias),info));u.mem_write(info,I(self.intern(b['filename'])));self.point(info+0xc,(b.get('offsetX',0),b.get('offsetY',0)));u.mem_write(info+0x14,bytes([int(b.get('have_variation',0)),int(b.get('emitt_on_walking',0))]))
   n=b['filename']
   if n in self.records or n not in self.particles['systems']:continue
   d=self.particles['systems'][n];p=E+0x20000+len(self.records)*0x200;self.records[n]=p
   u.mem_write(p,I(int(d.get('max_particles',100))));u.mem_write(p+4,I(int(d.get('num_release',1))))
   for off,v in [(8,d.get('release_interval',1)),(12,d.get('life_cycle',1)),(0x10,d.get('size',1)),(0x38,d.get('color',[1]*4)[0]),(0x3c,d.get('color',[1]*4)[1]),(0x40,d.get('color',[1]*4)[2]),(0x44,d.get('color',[1]*4)[3]),(0x48,d.get('velocity_var',0)),(0x6c,d.get('rot_speed',0))]:u.mem_write(p+off,F(v))
   u.mem_write(p+0x9c,I(E+0x51000));u.mem_write(p+0xb8,I(self.intern(d.get('child_system',''))))
  room=E+0x1000;map_obj=E+0x2000;creep_res=E+0x3000;u.mem_write(room+0xc,I(map_obj));u.mem_write(map_obj+8,I(map_field8));u.mem_write(creep_res+4,I(resource_kind));u.mem_write(creep_res+0x10,I(50));u.mem_write(creep_res+0x18,I(100));u.mem_write(creep_res+0x28,I(self.intern(name)));u.mem_write(creep_res+0x4c,I(E+0x4000))
  sp=STACK-0x2000;u.mem_write(sp,struct.pack('<5I',creep_res,0,0,BITS(1),0));u.reg_write(UC_ARM_REG_SP,sp);u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,room,0,1]):u.reg_write(reg,value)
  # Optional later join supplies a real source/graph after these explicit
  # resource records are installed. Existing constructor probes omit it.
  if hasattr(self,'prepare_constructor_context'):self.prepare_constructor_context()
  try:u.emu_start(0x78375,END,count=2000000)
  except Exception:
   Path(getattr(self,'failure_trace_path','builds/creep-constructor-r149-failure-trace.json')).write_text(json.dumps(list(self.trace),indent=2));raise
  assert u.reg_read(UC_ARM_REG_PC)==END,hex(u.reg_read(UC_ARM_REG_PC));assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  roots=[]
  for alias,node in self.slots.items():
   p=self.word(node+0x14);roots.append({'alias':alias,'pointer':p,'rate':self.word(p+4),'active':self.word(p+0xb8),'clock_bits':self.word(p+0xc0),'first_release':u.mem_read(p+0xd6,1)[0],'pool_head':self.word(p+0xe0),'active_head':self.word(p+0xdc),'delay_bits':self.word(p+0xbc),'release_bits':self.word(p+0xc4),'phase_bits':self.word(p+0xc8),'backup_rate':self.word(p+0xb0),'info_pointer':self.word(p+0xfc),'alpha_bits':self.word(p+0x44),'velocity_var_bits':self.word(p+0x48),'rotation_speed_bits':self.word(p+0x6c),'rgb_bits':[self.word(p+x) for x in [0x38,0x3c,0x40]],'life_bits':self.word(p+0xc),'size_bits':self.word(p+0x10),'interval_bits':self.word(p+8)})
  return {'resource':name,'map_field8':map_field8,'resource_kind':resource_kind,'roots':roots,'owner_fields':{'smoke':self.word(E+0x2c8),'poison':self.word(E+0x2cc),'radiation':self.word(E+0x2d0),'lsd':self.word(E+0x2d4),'freeze':self.word(E+0x2d8),'smoke_work_interval_bits':self.word(E+0x2e8),'smoke_base_interval_bits':self.word(E+0x2ec),'smoke_max_multiplier_bits':self.word(E+0x2f0),'smoke_rate':self.word(E+0x2f4),'smoke_color_flag':u.mem_read(E+0x2f8,1)[0]},'factories':self.factory_inputs,'param_calls':self.param_calls,'nonparticle_stubs':self.nonparticle}
def main():
 p=Constructor();cases=[]
 for n in range(1,11):
  for field in [1,2]:
   for kind in [1,2]:
    r=p.sample('creeps/creep'+str(n),field,kind)
    aliases=sorted(a for a in p.particles['bindings'][r['resource']] if 'explosion' not in a)
    assert [x['alias'] for x in r['roots']]==aliases
    assert all(x['active']==0 and x['clock_bits']==0 and x['first_release']==1 and x['pool_head']==0 and x['active_head']==0 and x['delay_bits']==0 and x['release_bits']==0 for x in r['roots'])
    pointers={x['alias']:x['pointer'] for x in r['roots']}
    for alias in ['smoke','poison','radiation','lsd','freeze']:assert r['owner_fields'][alias]==pointers.get(alias,0)
    assert all(x['rate']==0 for x in r['roots'] if x['alias'] in ['smoke','poison','radiation','lsd','freeze'])
    r['pointer_aliases_exact']=True;cases.append(r)
 assert all(bytes(p.u.mem_read(a,len(body)))==body for a,body in p.bodies.items()) and hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_executed_functions_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'supplied_particle_header_fields':{'0x0':'max_particles','0x4':'num_release','0x8':'release_interval','0xc':'life_cycle','0x10':'size','0x38..0x44':'colorRGBA','0x48':'velocity_var used by constructor smoke multiplier','0x6c':'rot_speed used by constructor smoke multiplier'},'other_particle_header_bytes':'supplied zero; texture pointer supplied and homogeneous classifier stub returns true; child string supplied','map_field8_semantic_meaning':'unassigned raw map+8 selector; values1/2 supplied, not an inferred map kind','resource_kind':'raw creep resource+4 selector supplied1/2','resource_parser':'omitted; scalar/vector2 creep parameter records and particle binding map entries supplied from preserved imports; string/vector-list unused by particle path and non-particle callbacks stubbed','cases':cases}
 Path('tests/fixtures/native-creep-particle-constructor-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'roots':sum(len(c['roots']) for c in cases),'full_function_bytes':data['full_function_bytes'],'all_new_roots_empty_zero_clock_first_release':True,'all_owner_pointer_aliases_exact':True,'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
