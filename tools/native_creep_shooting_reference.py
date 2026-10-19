"""R183 full original shooting direction, AngPos and AngleNormalize.
The original function authors its own facing table. Supplied std::map slots,
lexical traversal/erase and Python float64 atan callbacks replace only those
library calls. Full resource5/kind1 and resource4/kind2 C2/source/A*/normal
movement/position/direction/hover/source reroute bodies execute unchanged.
Graph/resources/room/player records and other R182 backend callbacks remain
supplied; no whole game, Apple libm, animation backend or GPU identity claim.
"""
from native_creep_air_path_reference import *
class ShootingConstructor(PlaneConstructor):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0x7dcac,0x110524,0x1106f8]:self.actual.add(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
  self.shoot_maps={};self.shoot_next={};self.shoot_trace=deque(maxlen=100)
 def hook(self,u,a,size,data):
  r0,r1,r2=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]];self.shoot_trace.append({'pc':hex(a),'r0':hex(r0),'r1':hex(r1),'lr':hex(u.reg_read(UC_ARM_REG_LR))})
  if a==0x7fc60:
   key=self.string(self.word(r1));m=self.shoot_maps.setdefault(r0,{})
   if key not in m:
    node=self.alloc(0x20);m[key]=node;u.mem_write(node+0x10,I(self.intern(key)))
   nodes=[m[k] for k in sorted(m)]
   u.mem_write(r0+0xc,I(nodes[0]));u.mem_write(r0+0x14,I(len(nodes)))
   for i,node in enumerate(nodes):self.shoot_next[node]=nodes[i+1] if i+1<len(nodes) else r0+4
   self.ret(m[key]+0x14);return
  if a==0x36c12c and r0 in self.shoot_next:self.ret(self.shoot_next[r0]);return
  if a==0x80304:self.shoot_maps.pop(r0,None);self.ret();return
  if a==0x36c3bc:
   value=struct.unpack('<d',struct.pack('<2I',r0,r1))[0];lo,hi=struct.unpack('<2I',struct.pack('<d',math.atan(value)));u.reg_write(UC_ARM_REG_R0,lo);u.reg_write(UC_ARM_REG_R1,hi);self.ret();return
  super().hook(u,a,size,data)

class Reference(ShootingConstructor):
 def __init__(self):
  self.table={};self.distances=[];self.query_bits=None;super().__init__()
 def hook(self,u,a,size,data):
  if a==0x80304:
   self.table={key:list(struct.unpack('<2I',u.mem_read(self.word(n+0x14),8))) for key,n in self.shoot_maps.get(u.reg_read(UC_ARM_REG_R0),{}).items()}
  if a==0x7e032:self.query_bits=u.reg_read(UC_ARM_REG_R0)
  if a==0x7e084:self.distances.append({'name':self.string(self.word(u.reg_read(UC_ARM_REG_R1)+0x10)),'distance_bits':u.reg_read(UC_ARM_REG_S0)})
  super().hook(u,a,size,data)
 def prepare_constructor_context(self):
  self.shoot_maps={};self.shoot_next={};super().prepare_constructor_context()
 def select(self,words):
  mark=self.heap;self.shoot_maps={};self.shoot_next={};self.distances=[];self.query_bits=None
  self.point(E+0x1a0,(0,0));self.u.mem_write(E+0x180,struct.pack('<2I',*words));PathProbe.call(self,0x7dcac,[E])
  row={'direction_bits':words,'primary':self.names.get(E+0x4c),'secondary':self.names.get(E+0xc0),'query_angle_bits':self.query_bits,'distances':self.distances.copy()};self.heap=mark;return row

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);parser.add_argument('--direct-only',action='store_true');args=parser.parse_args();out=Path(args.output);assert not out.exists();p=Reference()
 p.input={'source_cell':[4,4],'bases':[{'cell':[4,7],'owner':1,'inactive':False}],'source_owner':0,'source_target':0,'mask':'open','creep_number':5,'speed':1000};p.resource_name='creeps/creep5';p.sample(p.resource_name,1,1)
 direct=[]
 vectors=[(0.,0.),(-0.,0.),(0.,-0.),(-0.,-0.),(0,1),(1,0),(-1,0),(0,-1)]
 vectors += [(1000*math.cos(i*math.pi/180),1000*math.sin(i*math.pi/180)) for i in range(360)]
 # Sample true authored vectors and angular midpoints nearby at three scales.
 p.select([BITS(1),BITS(0)]);table=p.table.copy();headings=sorted(math.atan2(*reversed(struct.unpack('<2f',struct.pack('<2I',*v))))%(2*math.pi) for v in table.values())
 for scale in [.00001,1,1000]:
  for words in table.values():
   x,y=struct.unpack('<2f',struct.pack('<2I',*words));vectors.append((scale*x,scale*y))
  for i,a in enumerate(headings):
   b=headings[(i+1)%len(headings)]+(2*math.pi if i==len(headings)-1 else 0);middle=(a+b)/2
   for offset in [-.01,-.003,-.001,0,.001,.003,.01]:
    angle=middle+offset*math.pi/180;vectors.append((scale*math.cos(angle),scale*math.sin(angle)))
 for x,y in vectors:direct.append(p.select([BITS(x),BITS(y)]))
 print(json.dumps({'direct_cases':len(direct),'table_keys':sorted(table)}),flush=True)
 profiles=[('fresh',(4,4),[(10,10,1)],0,0,0),('walking',(4,4),[(10,10,1)],0,0,32),('approaching',(4,4),[(4,7,1)],0,0,2),('aligned',(10,9),[(10,10,1)],0,0,64),('targeted-walking',(4,4),[(10,10,1),(4,12,2)],0,1,32),('owned-aligned',(10,9),[(10,10,1),(4,7,2)],1,0,96)]
 rows=[]
 for number,profile,change in ([] if args.direct_only else itertools.product([5,4],profiles,['open','current'])):
  pose,start,bases,owner,target,warm=profile;p.input={'source_cell':start,'bases':[{'cell':[x,y],'owner':o,'inactive':False} for x,y,o in bases],'source_owner':owner,'source_target':target,'mask':'open','creep_number':number,'speed':1000};p.resource_name='creeps/creep'+str(number);p.constructor_arguments=[];p.sample(p.resource_name,1,1 if number==5 else 2);assert p.constructor_arguments==[[number,9001]];constructed=p.snapshot();warmup=[]
  for i in range(warm):dt=[0,30,100,16.667,133.333,30,100,100][i%8];Joined.step(p,dt);warmup.append({'frame':i,'delta':dt,'after':p.snapshot()})
  before=p.snapshot();source_before=SourcePathJoined.source_snapshot(p);blocked=[before['cell']] if change=='current' else []
  for cell in blocked:p.u.mem_write(p.cells[tuple(cell)]+0x18,b'\0')
  PathProbe.call(p,0xdbbe8,[p.source]);source_after=SourcePathJoined.source_snapshot(p);p.events=[];PathProbe.call(p,0x7ace0,[E,0]);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100]*8):Joined.step(p,dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{**p.input,'pose':pose},'change':{'kind':change,'blocked':blocked},'after_constructor':constructed,'warmup_frames':warmup,'source_cache_before':source_before,'source_cache_after':source_after,'after_replan':after,'frames':frames})
  print(json.dumps({'case':len(rows),'resource':number,'pose':pose,'change':change}),flush=True)
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'authored_table_bits':table,'directions':direct,'cases':rows};out.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'direct_cases':len(direct),'actor_cases':len(rows),'movement_frames':sum(len(r['warmup_frames'])+len(r['frames']) for r in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
