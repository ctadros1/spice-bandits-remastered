"""R175 full original normal rerouting with original A*, base selection and movement.
Full UpdateShortestPath, FindPathToBase, base availability/walkability, map
walkability, A*/smoothing, SetState/hover, displacement/free-slot, normal movement
and UpdatePosition execute unchanged. The16x16graph, valid actor/resource/base
records and selected constructor fields are supplied. No original graph or
resource producer, complete owner scheduling, combat shots, GPU or audio backend
runs. Existing animation/direction/sound and sinf/floorf callbacks remain explicit
recording/float32 math stubs. Supplied non-bomber/non-laser/non-kamikaze, one live
base and positive target availability do not establish every faction/target-loss
or special movement case. All paths below are actual original A* outputs.
"""
from pathlib import Path
import sys,json,struct,itertools,argparse,hashlib
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_approach_reference import *
from native_hex_path_reference import PathProbe
class ReplanJoined(Joined):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0x7ace0,0x7b5fc,0x7995c,0x105d14,0x106654,0x10be6c,0x7fb14,0x10bc40,0x10bcf8,0x7f95c,0x10b904,0x10b654,0x76640,0x103930,0xf92ac,0xf8fc0]:
   self.actual.append(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
 def hook(self,u,a,size,data):
  if a==0x7b5fc:self.events.append({'kind':'FindPathToBase-full','start':[u.reg_read(UC_ARM_REG_R1),u.reg_read(UC_ARM_REG_R2)],'force_start_walkable':u.reg_read(UC_ARM_REG_R3)})
  if a==0x7ace0:self.events.append({'kind':'UpdateShortestPath-full'})
  if a==0x10b904:self.events.append({'kind':'FreeDisplacePoint-full','cell':[u.reg_read(UC_ARM_REG_R1),u.reg_read(UC_ARM_REG_R2)],'owner':u.reg_read(UC_ARM_REG_R3)})
  super().hook(u,a,size,data)
 def invoke(self,address,args,stack=()):return PathProbe.call(self,address,args,stack)
 def setup_full(self,pose,base,mask):
  Joined.setup(self,2,base,.25,(1,1),2);u=self.u;actor=bytes(u.mem_read(E,0x400));resource=bytes(u.mem_read(E+0x2000,0x100));base_record=bytes(u.mem_read(E+0x9000,0x100));PathProbe.prepare_grid(self)
  u.mem_write(E,actor);u.mem_write(E+0x2000,resource);u.mem_write(E+0x2004,I(1));u.mem_write(E+0x9000,base_record);u.mem_write(E+0x901c,I(E+0x1000));self.trace=deque(maxlen=100)
  u.mem_write(E+0x4000,b''.join(I(self.cells[(4,y)]) for y in [6,7]));u.mem_write(E+0x40,struct.pack('<3I',E+0x4000,E+0x4008,E+0x4008));u.mem_write(0x40a110,I(0x47ed30));u.mem_write(0x47ed30,struct.pack('<3I',E+0x9300,E+0x9304,E+0x9304));u.mem_write(E+0x9300,I(E+0x9000));u.mem_write(E+0x172,b'\0');u.mem_write(E+0x138,I(9001));u.mem_write(E+0x1e8,F(123))
  constructor=next(x for x in json.load(open('tests/fixtures/native-creep-state-reference.json'))['constructors'] if x['resource']=='creeps/creep5' and x['map_field8']==1 and x['resource_kind']==1)
  self.point(E+0x54,(0,-5));u.mem_write(E+0x2c8,I(E+0x11000));u.mem_write(E+0x2e4,I(constructor['smoke_idle_multiplier_bits']));u.mem_write(E+0x2e8,I(constructor['smoke_work_interval_bits']));self.state(0)
  if pose=='walking-late':u.mem_write(E+0x158,F(.85));self.point(E+0x188,(308,288+64*.85))
  if pose in ['waiting','approaching','aligned']:
   u.mem_write(E+0x148,struct.pack('<2i',4,5));u.mem_write(E+0x150,struct.pack('<2i',4,5));self.point(E+0x188,(308,352));self.point(E+0x1a0,(308,352));self.point(E+0x180,(308,352));u.mem_write(E+0x158,F(0));u.mem_write(E+0x44,I(E+0x4000));self.state(1 if pose=='waiting' else 4)
  if pose in ['approaching','aligned']:
   self.point(E+0x70000,struct.unpack('<2f',u.mem_read(E+0x9064,8)));self.point(E+0x70100,(308,352));self.invoke(0x10b954,[self.map,4,5,9001],[E+0x70000,E+0x70100]);point=struct.unpack('<2f',u.mem_read(E+0x70100,8));self.point(E+0x23c,point)
   if pose=='approaching':u.mem_write(E+0x238,F(.25));self.point(E+0x188,tuple(308 if i==0 else 352+(point[i]-352)*.25 for i in range(2)))
   else:
    u.mem_write(E+0x236,b'\1');self.point(E+0x188,point);self.point(E+0x1a0,point);self.point(E+0x180,point)
  current=struct.unpack('<2i',u.mem_read(E+0x148,8));next_cell=struct.unpack('<2i',u.mem_read(E+0x150,8));blocked=[]
  if mask in ['current','both']:blocked.append(current)
  if mask in ['next','both']:blocked.append(next_cell)
  blocked=list(dict.fromkeys(blocked))
  for cell in blocked:u.mem_write(self.cells[cell]+0x18,b'\0')
  self.point(E+0x4c,struct.unpack('<2f',u.mem_read(E+0x188,8)));self.point(E+0xc0,struct.unpack('<2f',u.mem_read(E+0x188,8)));self.events=[];return blocked
 def snapshot(self):
  u=self.u;word=lambda o:struct.unpack('<I',u.mem_read(E+o,4))[0];begin,end=struct.unpack('<2I',u.mem_read(E+0x40,8));path=[]
  for p in range(begin,end,4):c=struct.unpack('<I',u.mem_read(p,4))[0];path.append(list(struct.unpack('<2i',u.mem_read(c+8,8))))
  return {'state':u.mem_read(E+0x170,1)[0],'hover':u.mem_read(E+0x34a,1)[0],'aligned':u.mem_read(E+0x236,1)[0],'progress_bits':word(0x158),'alignment_bits':word(0x238),'carry_bits':word(0x364),'start_bits':[word(0x1a0),word(0x1a4)],'target_bits':[word(0x180),word(0x184)],'attack_point_bits':[word(0x23c),word(0x240)],'position_bits':[word(0x4c),word(0x50)],'logical_bits':[word(0x188),word(0x18c)],'offset_bits':[word(0x54),word(0x58)],'phase_bits':word(0x344),'cell':[word(0x148),word(0x14c)],'next_cell':[word(0x150),word(0x154)],'working_interval_bits':word(0x2e8),'reload_bits':word(0x1e8),'path':path,'events':self.events.copy(),'displacement_owners':{str(x)+','+str(y):[-1 if v['free'] else v['owner'] for v in HexProbe.slots(self,(x,y))] for x,y in self.cells if self.u.mem_read(self.cells[(x,y)]+0xdc,1)[0]&1}}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=ReplanJoined();rows=[]
 for pose,base,mask in itertools.product(['walking-early','walking-late','waiting','approaching','aligned'],[(4,7),(4,10)],['open','current','next','both']):
  blocked=p.setup_full(pose,base,mask);before=p.snapshot();p.invoke(0x7ace0,[E,0]);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100,100,100,100,100]):p.step(dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{'pose':pose,'base_cell':base,'blocked':blocked,'resource':'creeps/creep5','base_distance':2,'speed':1000,'supplied_rof':1000000,'owner':9001,'geometry':{'base':44,'side':22,'height':64,'offset_x':0,'offset_y':0},'map_width':16,'map_height':16,'raw_bomber':False,'raw_laser':False,'raw_kamikaze':False},'before':before,'after_replan':after,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'movement_frames':sum(len(x['frames']) for x in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
