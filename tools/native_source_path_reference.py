"""R179 complete original source cached ground/air routes on a supplied graph.

Full CSource.UpdateShortestPath/CheckBases, CMap.FindShortestPath and original
A*/base walkability/vector helpers execute unchanged. A16x16 graph and valid
source/base records, owner/target ids and walk flags are explicit inputs.
No source constructor, room/manager population, resource producer, actor
constructor, kill/reward consumer, renderer/audio/GPU or whole game executes.
Cached source routes include their endpoints; actor constructor consumption
is a separate caller and must not be inferred from this helper alone.
"""
from native_creep_initial_path_reference import *

class SourcePathJoined(InitialPathJoined):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0xdbbe8,0xdc398,0x105cd8]:
   self.actual.append(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
  self.source=E+0x12000
 def prepare_source(self,start,bases,owner,target,mask):
  self.setup_full('walking-early',tuple(bases[0]['cell']),'open');u=self.u;self.source=E+0x12000
  template=bytes(u.mem_read(E+0x9000,0x100));self.base_records=[]
  for i,b in enumerate(bases):
   p=E+0x9400+i*0x100;self.base_records.append(p);u.mem_write(p,template);u.mem_write(p+0x44,struct.pack('<2i',*b['cell']));u.mem_write(p+0x54,I(b['owner']));u.mem_write(p+0x5c,F(0 if b['inactive'] else 1000));u.mem_write(p+0x6c,bytes([int(b['inactive'])]));self.point(p+0x64,(44+66*b['cell'][0],32+64*b['cell'][1]+(b['cell'][0]%2)*32))
  u.mem_write(E+0x9300,struct.pack('<'+'I'*len(bases),*self.base_records));u.mem_write(0x47ed30,struct.pack('<3I',E+0x9300,E+0x9300+4*len(bases),E+0x9300+4*len(bases)))
  u.mem_write(self.source,bytes(0x110));u.mem_write(self.source+0x1c,I(E+0x1000));u.mem_write(self.source+0x44,struct.pack('<4i',*start,owner,target));blocked=[]
  if mask=='source':blocked=[start]
  if mask=='wall':blocked=[(x,7) for x in range(16)]
  for cell in blocked:u.mem_write(self.cells[tuple(cell)]+0x18,b'\0')
  self.events=[];return blocked
 def source_snapshot(self):
  u=self.u;routes={}
  for name,offset in [('ground',0xf4),('air',0xe8)]:
   begin,end=struct.unpack('<2I',u.mem_read(self.source+offset,8));path=[]
   for p in range(begin,end,4):cell=struct.unpack('<I',u.mem_read(p,4))[0];path.append(list(struct.unpack('<2i',u.mem_read(cell+8,8))))
   routes[name]={'path':path,'base_index':next((i for i,p in enumerate(self.base_records) if p==struct.unpack('<I',u.mem_read(self.source+(0xe0 if name=='ground' else 0xe4),4))[0]),-1)}
  return {'target':struct.unpack('<I',u.mem_read(self.source+0x50,4))[0],'routes':routes,'base_cells_walkable':[u.mem_read(self.cells[tuple(struct.unpack('<2i',u.mem_read(p+0x44,8)))]+0x18,1)[0] for p in self.base_records]}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=SourcePathJoined();rows=[]
 profiles=[[{'cell':[10,10],'owner':0,'inactive':False}],[{'cell':[10,10],'owner':1,'inactive':False},{'cell':[4,12],'owner':2,'inactive':False}],[{'cell':[10,10],'owner':1,'inactive':True},{'cell':[4,12],'owner':2,'inactive':False}],[{'cell':[10,10],'owner':1,'inactive':True},{'cell':[4,12],'owner':2,'inactive':True}],[{'cell':[10,10],'owner':1,'inactive':False},{'cell':[4,5],'owner':2,'inactive':False}],[{'cell':[4,5],'owner':2,'inactive':False},{'cell':[10,10],'owner':1,'inactive':False}]]
 for bases,owner,target,mask in itertools.product(profiles,[0,1,2],[0,1,9],['open','source','wall']):
  start=(4,4);blocked=p.prepare_source(start,bases,owner,target,mask);before=p.source_snapshot();p.invoke(0xdbbe8,[p.source]);after=p.source_snapshot()
  rows.append({'input':{'source_cell':start,'source_owner':owner,'source_target':target,'bases':bases,'blocked':blocked,'mask':mask,'map_width':16,'map_height':16,'geometry':{'base':44,'side':22,'height':64,'offset_x':0,'offset_y':0}},'before':before,'after':after})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
