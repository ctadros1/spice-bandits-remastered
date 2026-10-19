"""R179 complete original creature constructor with real source cached paths.

Full CCreep.C2/particle factory/particle C2/SetState/hover, map-object and
animator constructors/Init, SetInitPosition and original source path producer/A*
execute unchanged. Resource/parameter/particle headers and graph/base/source
records are explicit supplied inputs. Resource binding, animator Play, random,
texture/registration/shooting-processor callbacks retain documented stubs.
Full normal movement/state/position/hover follows construction. Shooting
processor Process and shooting-direction/sound callbacks are recorded stubs;
sinf/floorf retain explicit float32 math callbacks. No original resource/room/
manager construction, shooting-processor backend or whole game executes.
AngPos retains the earlier zero-heading stub; final shooting/corner heading
is not an original-math/backend equivalence claim.
"""
from native_source_path_reference import *
from native_creep_state_reference import FullStateConstructor

class SpawnPathConstructor(FullStateConstructor):
 def __init__(self):
  super().__init__();self.reference=SourcePathJoined();self.actual=set(self.reference.actual)|set(self.reference.bodies)
  self.bodies.update(self.reference.bodies);fs=json.load(open('original/analysis/functions.json'))
  for a in [0x10a2c4,0x10ef20,0x10ef7c,0x11046c]:
   self.actual.add(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
  self.failure_trace_path='builds/creep-spawn-path-r179-first-failure-trace.json';self.events=[];self.names={}
 def hook(self,u,a,size,data):
  if a==0x798ec:self.events.append({'kind':'SetState-full','old':u.mem_read(E+0x170,1)[0],'new':u.reg_read(UC_ARM_REG_R1)})
  if a==0x10b654:self.events.append({'kind':'IsCellWalkable-full','map':hex(u.reg_read(UC_ARM_REG_R0)),'cell':[u.reg_read(UC_ARM_REG_R1),u.reg_read(UC_ARM_REG_R2)]})
  if a in self.actual:return
  if a==0x10f0cc:self.names[u.reg_read(UC_ARM_REG_R0)]=self.string(u.reg_read(UC_ARM_REG_R1));self.ret();return
  if a==0x36c97c:self.ret(len(self.string(u.reg_read(UC_ARM_REG_R0))));return
  if a==0x36c00c:
   r0,r1=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1]];u.mem_write(r0,I(r1));self.ret(r0);return
  if a==0x11c9a8:self.ret(E+0x188000);return # supplied animation group, Play stays recorded
  if a==0x110524:self.ret(0);return # same explicit heading stub as R177
  if a==0x36cafc:
   r0,r1=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1]];assert r1;self.ret(r0%r1);return
  if a==0x120520:self.events.append({'kind':'sound-load-stub','name':self.string(u.reg_read(UC_ARM_REG_R0))});self.ret(0);return
  if a==0x763a8:self.events.append({'kind':'base-damage-stub','amount_bits':u.reg_read(UC_ARM_REG_R1)});self.ret();return
  if a==0x10f01c:self.ret(self.intern(self.names.get(u.reg_read(UC_ARM_REG_R0),'RunDownRight')));return
  if a in [0x7dcac,0x11f75c,0x82140]:self.events.append({'kind':'recording-callback','address':hex(a)});self.ret();return
  if a==0x36c4dc:self.ret(BITS(math.floor(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0])));return
  if a==0x36c88c:self.ret(BITS(math.sin(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0])));return
  if a==0x36c6bc:
   r0,r1,r2=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]];u.mem_write(r0,bytes(u.mem_read(r1,r2)));self.ret(r0);return
  if a==0x36c18c:self.ret();return
  super().hook(u,a,size,data)
 def prepare_constructor_context(self):
  ref=self.reference;ref.prepare_source(tuple(self.input['source_cell']),self.input['bases'],self.input['source_owner'],self.input['source_target'],self.input['mask']);u=self.u;delta=0xe0000
  def relocated(value):return value+delta if E+0x20000<=value<E+0x90000 else value
  raw=bytes(ref.u.mem_read(E+0x20000,0x70000));words=struct.unpack('<'+'I'*(len(raw)//4),raw);u.mem_write(E+0x100000,struct.pack('<'+'I'*len(words),*(relocated(x) for x in words)))
  self.cells={xy:relocated(p) for xy,p in ref.cells.items()};self.map=relocated(ref.map);self.base_records=[]
  for i,old in enumerate(ref.base_records):
   p=E+0x180000+i*0x100;self.base_records.append(p);u.mem_write(p,bytes(ref.u.mem_read(old,0x100)));u.mem_write(p+0x1c,I(E+0x2000))
  self.source=E+0x184000;u.mem_write(self.source,bytes(ref.u.mem_read(ref.source,0x110)));u.mem_write(self.source+0x1c,I(E+0x2000))
  u.mem_write(E+0x185000,struct.pack('<'+'I'*len(self.base_records),*self.base_records));u.mem_write(0x40a110,I(0x47ed30));u.mem_write(0x47ed30,struct.pack('<3I',E+0x185000,E+0x185000+4*len(self.base_records),E+0x185000+4*len(self.base_records)))
  u.mem_write(E+0x2074,I(self.map));u.mem_write(0x40a26c,I(MEMORY+0xf000));u.mem_write(0x47eda0,F(64));self.heap=E+0x210000;self.events=[];self.names={}
  saved={r:u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3,UC_ARM_REG_SP,UC_ARM_REG_LR]}
  PathProbe.call(self,0xdbbe8,[self.source]);self.cached_source=SourcePathJoined.source_snapshot(self)
  # Supply valid string-vector parameter records used by the original
  # first-shot sound selector. Resource parsing/audio loading remain stubs.
  for key,values in self.animations[self.resource_name]['params'].items():
   if isinstance(values,list) and values and all(isinstance(x,str) for x in values):
    vector=self.alloc(4*len(values));u.mem_write(vector,struct.pack('<'+'I'*len(values),*(self.intern(x) for x in values)));u.mem_write(self.params[key]+0x1c,struct.pack('<3I',vector,vector+4*len(values),vector+4*len(values)))
  for r,value in saved.items():u.reg_write(r,value)
  u.mem_write(saved[UC_ARM_REG_SP]+4,I(self.source));u.reg_write(UC_ARM_REG_R2,5);u.reg_write(UC_ARM_REG_R3,9001)
  for off,value in [(0x10,1000000),(0x14,1000),(0x34,2)]:u.mem_write(E+0x3000+off,I(value))
 def snapshot(self):
  u=self.u;word=lambda o:struct.unpack('<I',u.mem_read(E+o,4))[0];begin,end=struct.unpack('<2I',u.mem_read(E+0x40,8));path=[]
  for p in range(begin,end,4):c=struct.unpack('<I',u.mem_read(p,4))[0];path.append(list(struct.unpack('<2i',u.mem_read(c+8,8))))
  row=ReplanJoined.snapshot(self)
  row.update({'aim_bits':[word(0x190),word(0x194)],'secondary_position_bits':[word(0xc0),word(0xc4)],'raw_hit_pending':u.mem_read(E+0x2b0,1)[0],'remaining_count':word(0x2b4),'previous_progress_bits':word(0x15c),'position_flags':list(u.mem_read(E+0x2a0,5)),'segment_relation':u.mem_read(E+0x358,1)[0],'portal_state':word(0x354),'portal_clock_bits':word(0x350),'portal_marker':list(struct.unpack('<2i',u.mem_read(E+0x168,8)))})
  row['walking_animator']={'primary':self.names.get(E+0x4c,''),'secondary':self.names.get(E+0xc0,''),'rotation_bits':word(0x7c),'alpha_bits':word(0x80),'secondary_rotation_bits':word(0xf0),'secondary_alpha_bits':word(0xf4)}
  row.update({'base_index':next((i for i,p in enumerate(self.base_records) if p==word(0x258)),-1),'speed_bits':word(0x224),'primary':self.names.get(E+0x4c,''),'secondary':self.names.get(E+0xc0,''),'source_cell_walkable':u.mem_read(self.cells[tuple(self.input['source_cell'])]+0x18,1)[0],'events':self.events.copy()})
  return row

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=SpawnPathConstructor();rows=[]
 for start,(base,inactive),(owner,target),mask in itertools.product([(4,4),(10,9)],[((10,10),False),((4,7),False),((10,10),True)],[(0,0),(0,1),(2,0),(2,1)],['open','source','wall']):
  p.input={'source_cell':start,'bases':[{'cell':base,'owner':1,'inactive':inactive}],'source_owner':owner,'source_target':target,'mask':mask};p.resource_name='creeps/creep5';result=p.sample(p.resource_name,1,1);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100]*8):Joined.step(p,dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':p.input,'source_cache':p.cached_source,'after_constructor':after,'supplied_resource':'creeps/creep5','frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(rows),'movement_frames':sum(len(r['frames']) for r in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
