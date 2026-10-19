"""R173 complete original GetFirstMovementPoint and displacement references.
GetCell, IsCellsHLinked, CreateDisplacePoints, GetDisplacePointInHexagon,
integer/float GetDist2D and CDisPoint vector push_back execute unchanged on
supplied map/cell/vector records and a supplied global hex distance. Explicit
new/delete/memcpy/memmove/exception callbacks model memory only. External floorf
is a supplied float32 recording stub. No resource parser, route builder,
original map/global producer, complete movement owner, audio or GPU executes.
"""
from pathlib import Path
import sys,struct,math,json,argparse,itertools
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_reference import *
class HexProbe(Probe):
 def __init__(self):
  super().__init__();self.heap=E+0x80000;self.trace=[];self.cells={};self.events=[]
  fs=json.load(open('original/analysis/functions.json'));self.addresses=[0x7ba04,0x1066fc,0x10bca4,0x10b954,0x10bebc,0x1104e0,0x1104b0,0x10c0cc]
  self.bodies={a:bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a))) for a in self.addresses}
 def hook(self,u,a,size,data):
  self.trace.append(hex(a));self.trace=self.trace[-100:]
  if a in self.addresses:return
  r0,r1,r2=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a==0x36c1bc:
   p=self.heap;self.heap+=(r0+15)&~15;u.mem_write(p,bytes(r0));self.ret(p);return
  if a==0x36c18c:self.ret();return
  if a in [0x36c6ac,0x36c6bc]:u.mem_write(r0,bytes(u.mem_read(r1,r2)));self.ret(r0);return
  if a==0x36c4dc:self.events.append({'kind':'floorf-stub','input_bits':r0});self.ret(BITS(math.floor(struct.unpack('<f',I(r0))[0])));return
  if a==0x36ca7c:self.ret();return
  super().hook(u,a,size,data)
 def setup(self,coords):
  u=self.u;u.mem_write(E,bytes(0x90000));self.heap=E+0x80000;self.cells={};self.events=[];self.trace=[]
  self.map=E+0x20000;rows=E+0x20100;u.mem_write(self.map,I(rows));u.mem_write(self.map+0x24,I(16));u.mem_write(self.map+0x28,I(16))
  for y in range(16):u.mem_write(rows+y*12,struct.pack('<3I',E+0x21000+y*0x100,E+0x21000+y*0x100+64,E+0x21000+y*0x100+64))
  for i,(x,y) in enumerate(coords):
   cell=E+0x30000+i*0x200;self.cells[(x,y)]=cell;u.mem_write(cell+8,struct.pack('<2i',x,y));self.point(cell+0x10,(100+x*32,100+y*32));u.mem_write(cell+0x1c,F(1));u.mem_write(E+0x21000+y*0x100+x*4,I(cell))
  u.mem_write(E+0x1c,I(E+0x1000));u.mem_write(E+0x1074,I(self.map));u.mem_write(E+0x250,I(E+0x2000));u.mem_write(0x47eda0,F(64))
 def call(self,address,args,stack=()):
  u=self.u;self.stop=END;sp=STACK-0x100;u.reg_write(UC_ARM_REG_SP,sp);u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,val in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],list(args)+[0]*4):u.reg_write(reg,val&0xffffffff)
  if stack:u.mem_write(sp,struct.pack('<'+'I'*len(stack),*stack))
  try:u.emu_start(address|1,END,count=200000)
  except Exception:print(json.dumps({'pc':hex(u.reg_read(UC_ARM_REG_PC)),'trace':self.trace,'events':self.events}));raise
  assert u.reg_read(UC_ARM_REG_PC)==END
  assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  return u.reg_read(UC_ARM_REG_R0)
 def slots(self,coord):
  u=self.u;cell=self.cells[coord];begin,end=struct.unpack('<2I',u.mem_read(cell+0xe0,8));result=[]
  for address in range(begin,end,4):
   point=struct.unpack('<I',u.mem_read(address,4))[0];result.append({'point':list(struct.unpack('<2f',u.mem_read(point,8))),'free':u.mem_read(point+8,1)[0],'owner':struct.unpack('<I',u.mem_read(point+12,4))[0]})
  return result
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=HexProbe();route=[];displacement=[]
 for axis,count,distance,state,linked,consume,present in itertools.product(['horizontal','ordinary'],range(6),[-1,0,1,2,3,4,5],[0,7],[False,True],[False,True],[False,True]):
  head=(6,4) if axis=='horizontal' else (4,6);coords=[head]+([(4,4)] if present else []);p.setup(coords);u=p.u
  cell=p.cells[head];u.mem_write(cell+0xa0,I(1));u.mem_write(cell+0x80,I(p.cells.get((4,4),0)));u.mem_write(cell+0xa4,I(int(linked)));vector=E+0x4000
  u.mem_write(vector,I(cell)*count);u.mem_write(E+0x40,struct.pack('<3I',vector,vector+count*4,vector+count*4));u.mem_write(E+0x148,struct.pack('<2i',4,4));u.mem_write(E+0x2034,I(distance&0xffffffff));u.mem_write(E+0x170,bytes([state]));u.mem_write(E+0x22c,F(0));u.mem_write(E+0x15c,F(7));p.point(E+0x5000,(-9,-9));u.mem_write(E+0x5100,I(99));u.mem_write(E+0x5200,I(99))
  result=p.call(0x7ba04,[E,E+0x5000,E+0x5100,E+0x5200],[int(consume)]);begin,end=struct.unpack('<2I',u.mem_read(E+0x40,8))
  route.append({'input':{'axis':axis,'count':count,'base_distance':distance,'state':state,'link_marked':linked,'consume':consume,'current_cell_present':present},'after':{'allowed':bool(result),'remaining_count':(end-begin)//4,'point_bits':list(struct.unpack('<2I',u.mem_read(E+0x5000,8))),'cell':[struct.unpack('<i',u.mem_read(E+o,4))[0] for o in [0x5100,0x5200]],'raw_remaining_field':struct.unpack('<I',u.mem_read(E+0x2b4,4))[0],'multiplier_bits':struct.unpack('<I',u.mem_read(E+0x22c,4))[0],'raw_15c_bits':struct.unpack('<I',u.mem_read(E+0x15c,4))[0]},'callbacks':p.events.copy()})
 for coord,height,offset in itertools.product([(0,0),(0,4),(4,0),(4,4),(15,15)],[48,62,64],[(0,0),(100,0),(0,100),(100,100),(-100,-100)]):
  p.setup([coord]);u=p.u;u.mem_write(0x47eda0,F(height));center=struct.unpack('<2f',u.mem_read(p.cells[coord]+0x10,8));toward=tuple(center[i]+offset[i] for i in range(2));p.point(E+0x5000,toward);frames=[]
  for owner in range(10):
   p.point(E+0x5100,(-9,-9));p.call(0x10b954,[p.map,*coord,owner],[E+0x5000,E+0x5100]);frames.append({'owner':owner,'point_bits':list(struct.unpack('<2I',u.mem_read(E+0x5100,8))),'slots':p.slots(coord)})
  displacement.append({'input':{'cell':coord,'hex_distance':height,'toward':toward,'center':center},'frames':frames})
 invalid=[]
 for coord in [(-1,4),(4,-1),(16,4),(4,16),(2,2)]:
  p.setup([(4,4)]);u=p.u;p.point(E+0x5000,(500,500));p.point(E+0x5100,(-9,-9));p.call(0x10b954,[p.map,*coord,42],[E+0x5000,E+0x5100]);invalid.append({'cell':coord,'point_bits':list(struct.unpack('<2I',u.mem_read(E+0x5100,8)))})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'route_head_cases':route,'displacement_sequences':displacement,'invalid_displacement_cases':invalid};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'route_head_cases':len(route),'displacement_sequences':len(displacement),'displacement_calls':sum(len(x['frames']) for x in displacement),'invalid_cases':len(invalid),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
