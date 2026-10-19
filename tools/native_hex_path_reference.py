"""R175 complete original pathfinder on a supplied sixteen-by-sixteen graph.
Original CMap wrapper, CHexMap A* and smoothing/vector helpers execute unchanged.
The graph, cell world/grid coordinates, link order/types/intermediate links,
walk flags and per-owner penalties are supplied; the original graph/resource
producer and whole game do not run. Memory/exception callbacks are explicit.
"""
import sys,json,struct
from pathlib import Path
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_hex_reference import *
class PathProbe(HexProbe):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0x105d14,0x106654,0x10be6c,0x7fb14,0x10bc40,0x10bcf8,0x7f95c]:
   self.addresses.append(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
 def call(self,address,args,stack=()):
  u=self.u;self.stop=END;sp=STACK-0x100;u.reg_write(UC_ARM_REG_SP,sp);u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,val in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],list(args)+[0]*4):u.reg_write(reg,val&0xffffffff)
  if stack:u.mem_write(sp,struct.pack('<'+'I'*len(stack),*stack))
  u.emu_start(address|1,END,count=2000000)
  assert u.reg_read(UC_ARM_REG_PC)==END,{'pc':hex(u.reg_read(UC_ARM_REG_PC)),'trace':self.trace,'events':self.events}
  assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  return u.reg_read(UC_ARM_REG_R0)
 def prepare_grid(self):
  HexProbe.setup(self,[(x,y) for y in range(16) for x in range(16)]);u=self.u
  for (x,y),cell in self.cells.items():
   center=(44+x*66,32+y*64+(x%2)*32);u.mem_write(cell,struct.pack('<2i',*center));self.point(cell+0x10,center);u.mem_write(cell+0x18,b'\1')
   for owner in range(16):u.mem_write(cell+0x30+owner*4,F(1))
   odd=x%2;ds=[(0,-1),(1,0),(-1,0),(0,1),(-1,-1 if not odd else 1),(1,-1 if not odd else 1)]
   if x==0:
    ds=[(0,-1),(0,1),(1,0),(1,-1)]
    if y==0:ds=[(0,1),(1,0)]
    elif y==15:ds=[(0,-1),(1,-1),(1,0)]
   elif x==15:
    ds=[(0,-1),(-1,0),(-1,-1 if not odd else 1),(0,1)]
    if y==0:ds=[(-1,0),(0,1),(-1,1)] if odd else [(-1,0),(0,1)]
    elif y==15:ds=[(0,-1),(-1,0)] if odd else [(0,-1),(-1,-1),(-1,0)]
   elif y==0:ds=[(-1,0),(1,0),(0,1)]+([(1,1),(-1,1)] if odd else [])
   elif y==15:ds=[(-1,0),(1,0),(0,-1)]+([(1,-1),(-1,-1)] if not odd else [])
   ns=[(x+dx,y+dy) for dx,dy in ds+[(-2,0),(2,0)] if (x+dx,y+dy) in self.cells];u.mem_write(cell+0xa0,I(len(ns)))
   for i,n in enumerate(ns):u.mem_write(cell+0x80+i*4,I(self.cells[n]));u.mem_write(cell+0xa4+i*4,I(1 if n==(x-2,y) else (2 if n==(x+2,y) else 0)))
   for dx,off in [(-1,0xcc),(1,0xd4)]:
    mid=(x+dx,y);alt=(x+dx,y+(1 if (x+dx)%2==0 else -1))
    for i,c in enumerate([mid,alt]):u.mem_write(cell+off+i*4,I(self.cells.get(c,0)))
 def path(self,start,end):
  self.trace=[];self.events=[];u=self.u;result=E+0x70000;vector=E+0x70100;u.mem_write(vector,bytes(12));self.call(0x106654,[result,E+0x1000,*start],[*end,vector,0,0,0]);begin,finish=struct.unpack('<2I',u.mem_read(vector,8));coords=[]
  for p in range(begin,finish,4):c=struct.unpack('<I',u.mem_read(p,4))[0];coords.append(list(struct.unpack('<2i',u.mem_read(c+8,8))))
  return {'start':start,'end':end,'path':coords,'result':list(struct.unpack('<2I',u.mem_read(result,8)))}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=PathProbe();p.prepare_grid();rows=[]
 for start,end in [((4,4),(4,10)),((4,5),(4,10)),((4,4),(4,4)),((0,0),(2,2)),((4,4),(10,10)),((0,0),(15,15))]:rows.append(p.path(start,end))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
