"""R174 full original normal movement/state/position/hover with route and slots.
Full original movement, SetState/hover, UpdatePosition, GetFirstMovementPoint,
GetCell, IsCellsHLinked, GetDisplacePointInHexagon/CreateDisplacePoints and
integer/float distance bodies execute on supplied valid map/cell/path/base
records. Standard new/delete/memcpy/memmove/exception callbacks are memory
stubs; external floorf/sinf use explicit float32 Python math callbacks. Existing
animation-name/direction and sound Stop callbacks are recording stubs. No full
route builder, resource/actor/room/global initialization, combat shots, renderer,
audio backend or original GPU executes. Non-kamikaze input is supplied; the
separate impact/shooting/target-loss and path-replan joins remain open.
"""
from pathlib import Path
import sys,json,struct,math,itertools,argparse,hashlib
from collections import deque
sys.path[:0]=[str(Path('tools').resolve())]
from native_creep_hex_reference import HexProbe
from native_creep_hover_movement_reference import *
class Joined(FullMovement):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'));self.actual=[0x7ba04,0x1066fc,0x10bca4,0x10b954,0x10bebc,0x1104e0,0x1104b0,0x10c0cc]
  for a in self.actual:self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
  self.heap=E+0x80000;self.events=[]
 def hook(self,u,a,size,data):
  r0,r1,r2=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a in self.actual:
   if a in [0x7ba04,0x10b954]:self.events.append({'kind':'original-call','method':hex(a)})
   self.trace.append(hex(a));return
  if a==0x36c1bc:
   p=self.heap;self.heap+=(r0+15)&~15;u.mem_write(p,bytes(r0));self.ret(p);return
  if a==0x36c18c:self.ret();return
  if a in [0x36c6ac,0x36c6bc]:u.mem_write(r0,bytes(u.mem_read(r1,r2)));self.ret(r0);return
  if a==0x36c4dc:self.ret(BITS(math.floor(struct.unpack('<f',I(r0))[0])));return
  if a==0x7dcac:self.events.append({'kind':'shoot-direction-stub'});self.ret();return
  if a==0x11f75c:self.events.append({'kind':'sound-stop-stub'});self.ret();return
  if a==0x798ec:self.events.append({'kind':'SetState-full','old':u.mem_read(E+0x170,1)[0],'new':r1,'caller':hex(u.reg_read(UC_ARM_REG_LR))})
  super().hook(u,a,size,data)
 def setup(self,count=0,base=(4,10),progress=1,flags=(1,0),stand_off=2):
  coords=list(dict.fromkeys([(4,4),(4,5),base]+[(4,6+i) for i in range(count)]));HexProbe.setup(self,coords);self.trace=deque(maxlen=100);u=self.u
  self.current='RunDown';self.names={E+0x4c:'RunDown',E+0xc0:'RunDown'}
  for (x,y),cell in self.cells.items():self.point(cell+0x10,(44+x*66,32+y*64+(x%2)*32))
  def world(cell):return struct.unpack('<2f',u.mem_read(self.cells[cell]+0x10,8))
  current,next_point=world((4,4)),world((4,5));self.point(E+0x1a0,current);self.point(E+0x180,next_point);self.point(E+0x188,tuple(current[i]+(next_point[i]-current[i])*progress for i in range(2)));u.mem_write(E+0x158,F(progress));u.mem_write(E+0x224,F(1000));u.mem_write(E+0x2a0,b'\x01');u.mem_write(E+0x2a3,b'\x01');u.mem_write(E+0x34,F(1));u.mem_write(E+0x348,bytes([*flags,0]));u.mem_write(0x40a1ec,I(MEMORY+9000));u.mem_write(MEMORY+9000,F(64))
  resource=E+0x2000;u.mem_write(E+0x250,I(resource));u.mem_write(resource+0x10,I(1000000));u.mem_write(resource+0x14,I(1000));u.mem_write(resource+0x34,I(stand_off));base_ptr=E+0x9000;u.mem_write(E+0x258,I(base_ptr));u.mem_write(base_ptr+0x44,struct.pack('<2i',*base));u.mem_write(base_ptr+0x5c,F(1000));self.point(base_ptr+0x64,world(base))
  u.mem_write(E+0x148,struct.pack('<2i',4,4));u.mem_write(E+0x150,struct.pack('<2i',4,5));vector=E+0x4000
  for i in range(count):u.mem_write(vector+i*4,I(self.cells[(4,6+i)]))
  u.mem_write(E+0x40,struct.pack('<3I',vector,vector+count*4,vector+count*4));self.state(0);self.events=[]
 def step(self,dt=30):
  self.calls=[];self.events=[];self.trace.clear();self.position_calls=0;self.stop=END;self.movement_mode=True;u=self.u;u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,BITS(dt));u.reg_write(UC_ARM_REG_R2,0)
  try:u.emu_start(0x7bfa9,END,count=300000)
  except Exception:print(json.dumps({'pc':hex(u.reg_read(UC_ARM_REG_PC)),'events':self.events,'trace':list(self.trace)}));raise
  assert u.reg_read(UC_ARM_REG_PC)==END and all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  word=lambda o:struct.unpack('<I',u.mem_read(E+o,4))[0]
  return {'state':u.mem_read(E+0x170,1)[0],'hover':u.mem_read(E+0x34a,1)[0],'aligned':u.mem_read(E+0x236,1)[0],'progress_bits':word(0x158),'alignment_bits':word(0x238),'logical_bits':[word(0x188),word(0x18c)],'position_bits':[word(0x4c),word(0x50)],'offset_bits':[word(0x54),word(0x58)],'phase_bits':word(0x344),'cell':[word(0x148),word(0x14c)],'next_cell':[word(0x150),word(0x154)],'working_interval_bits':word(0x2e8),'aim_bits':[word(0x190),word(0x194)],'reload_bits':word(0x1e8),'events':self.events.copy(),'sinf_stub':self.calls.copy(),'displacement_owners':{str(x)+','+str(y):[-1 if v['free'] else v['owner'] for v in HexProbe.slots(self,(x,y))] for x,y in self.cells if self.u.mem_read(self.cells[(x,y)]+0xdc,1)[0]&1}}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=Joined();cases=[]
 constructors=json.load(open('tests/fixtures/native-creep-state-reference.json'))['constructors'];params=json.load(open('game/data/catalog.json'))['resource_params']
 for number,count,base,progress,stand_off,delta in itertools.product([2,5,6],[0,2],[(4,7),(4,10),(10,10)],[.5,1],[2,4],[0,30,100]):
  resource='creeps/creep'+str(number);c=next(x for x in constructors if x['resource']==resource and x['map_field8']==1 and x['resource_kind']==1);p.setup(count,base,progress,(c['hover348'],c['hover349']),stand_off);u=p.u
  offset=params[resource].get('offset',[0,0]);p.point(E+0x54,offset);u.mem_write(E+0x2c8,I(E+0x11000));u.mem_write(E+0x2e4,I(c['smoke_idle_multiplier_bits']));u.mem_write(E+0x2e8,I(c['smoke_work_interval_bits']));u.mem_write(E+0x138,I(9001));frames=[]
  for frame in range(16):frames.append({'frame':frame,'after':p.step(delta)})
  cases.append({'input':{'resource':resource,'remaining_route':[[4,6+i] for i in range(count)],'base_cell':base,'current_cell':[4,4],'next_cell':[4,5],'progress':progress,'base_distance':stand_off,'delta':delta,'speed':1000,'hex_distance':64,'map_width':16,'map_height':16,'geometry':{'base':44,'side':22,'height':64,'offset_x':0,'offset_y':0},'offset':offset,'hover348':c['hover348'],'hover349':c['hover349'],'smoke_multiplier_bits':c['smoke_idle_multiplier_bits'],'working_interval_bits':c['smoke_work_interval_bits'],'owner':9001,'raw_kamikaze':False,'supplied_rof':1000000},'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':cases};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(x['frames']) for x in cases),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
