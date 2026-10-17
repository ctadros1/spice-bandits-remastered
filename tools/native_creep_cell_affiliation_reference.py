"""R161 bounded original map Load cell-affiliation assignment slice.
Original0x100b12..0x100b66 (84bytes) executes with supplied map/grid/row/cell/
stack records. XML getChildNode/getText/destructor and integer atoi are stubs;
child name is read from original instructions/data. No full Load/XML parser,
cell constructor, runtime map mutation, room/game/pathfinder/GPU executes.
"""
from native_creep_reference import *
MAP=E+0x1000;GRID=E+0x2000;ROWS=E+0x3000;ROW=E+0x4000;CELL=E+0x5000
class Affiliation(Probe):
 def __init__(self):
  super().__init__();self.body=bytes(self.u.mem_read(0x100b12,84));self.calls=[];self.value=None
 def hook(self,u,a,size,data):
  if a==0x124320:self.calls.append({'call':'getChildNode-stub','original_key':self.string(u.reg_read(UC_ARM_REG_R2))});self.ret();return
  if a==0x1243c4:self.calls.append({'call':'getText-stub','supplied':self.value});self.ret(0 if self.value is None else self.intern(self.value));return
  if a==0x1230c0:self.calls.append({'call':'XMLNodeDestructor-stub'});self.ret();return
  if a==0x36c3dc:
   text=self.string(u.reg_read(UC_ARM_REG_R0));self.calls.append({'call':'atoi-stub','supplied':text});self.ret(int(text or '0')&0xffffffff);return
  super().hook(u,a,size,data)
 def sample(self,value,y,x):
  self.calls=[];self.value=value;u=self.u;u.mem_write(E,bytes(0x8000));u.mem_write(MAP+0x74,I(GRID));u.mem_write(GRID,I(ROWS));u.mem_write(ROWS+y*4,I(ROW));u.mem_write(ROW+x*4,I(CELL));u.mem_write(CELL+0x108,I(0xdeadbeef));sp=STACK-0x1000;u.mem_write(sp+0x58,struct.pack('<3I',MAP,y,x));u.reg_write(UC_ARM_REG_SP,sp);self.stop=0x100b66;u.emu_start(0x100b13,self.stop,count=20000);assert u.reg_read(UC_ARM_REG_PC)==self.stop and bytes(u.mem_read(0x100b12,84))==self.body
  assert self.calls[0]['original_key']=='p'
  result=struct.unpack('<I',u.mem_read(CELL+0x108,4))[0];assert result==((1 if value is None else int(value or '0'))&0xffffffff)
  return {'supplied_getText':value,'row':y,'column':x,'cell108':result,'calls':self.calls.copy()}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-cell-affiliation-reference.json');args=parser.parse_args();p=Affiliation();cases=[p.sample(value,y,x) for value in [None,'','0','1','2','3','-1','2147483647','-2147483648'] for y,x in [(0,0),(1,2)]];maps=[]
 for name,m in sorted(json.load(open('game/data/maps.json')).items()):
  counts={};missing=0
  for cell in m['cells']:
   if 'p' not in cell:missing+=1
   n=str(cell.get('p',1));counts[n]=counts.get(n,0)+1
  maps.append({'map':name,'cells':len(m['cells']),'p_counts':counts,'missing_p':missing})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'slice':{'start':'0x100b12','stop':'0x100b66','bytes':84,'sha256':hashlib.sha256(p.body).hexdigest()},'original_unchanged':True,'cases':cases,'preserved_imported_maps':maps};path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'maps':len(maps),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
