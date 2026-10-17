"""R152 original map theme selector and bounded Load assignment.
Execute full GetThemeByName184bytes and its full ismatch40byte helper without
stubs; separately execute Load0xfffa8..0xfffbc with supplied getText result
and map/stack pointers. XML parsing and the remaining Load body do not run.
No original file/function bytes are modified; no game/GPU/room executes.
"""
from native_creep_reference import *
class Theme(Probe):
 def __init__(self):
  super().__init__();self.compared=[]
  self.full={0x103338:bytes(self.u.mem_read(0x103338,184)),0x122020:bytes(self.u.mem_read(0x122020,40))}
  self.load_slice=bytes(self.u.mem_read(0xfffa8,20))
 def hook(self,u,a,size,data):
  if a==0x122020:self.compared.append(self.string(u.reg_read(UC_ARM_REG_R1)))
  super().hook(u,a,size,data)
 def sample(self,name,assignment=False):
  self.compared=[];self.stop=0xfffbc if assignment else END;sp=STACK-0x1000
  self.u.reg_write(UC_ARM_REG_SP,sp);self.u.reg_write(UC_ARM_REG_LR,END|1)
  pointer=0 if name is None else self.intern(name)
  self.u.reg_write(UC_ARM_REG_R0,pointer)
  if assignment:
   self.u.mem_write(sp+0x5c,I(pointer));self.u.mem_write(sp+0x58,I(E));self.u.mem_write(E+8,I(0xdeadbeef))
  self.u.emu_start(0xfffa9 if assignment else 0x103339,self.stop,count=20000)
  assert self.u.reg_read(UC_ARM_REG_PC)==self.stop
  result=struct.unpack('<I',self.u.mem_read(E+8,4))[0] if assignment else self.u.reg_read(UC_ARM_REG_R0)
  assert all(bytes(self.u.mem_read(a,len(b)))==b for a,b in self.full.items()) and bytes(self.u.mem_read(0xfffa8,20))==self.load_slice
  return {'input':name,'selector':result,'compared_original_names':self.compared.copy()}
def main():
 p=Theme();maps=json.load(open('game/data/maps.json'));p.sample('__unknown__');names=list(dict.fromkeys(p.compared));inputs=[None,'','__unknown__']+names+[x.upper() for x in names]+[x+' ' for x in names]+sorted({str(x.get('theme','')) for x in maps.values()})
 cases=[]
 for name in inputs:
  a=p.sample(name);b=p.sample(name,True);assert a==b;cases.append(a)
 mapped=[]
 for key,value in sorted(maps.items()):
  row=p.sample(value.get('theme'),True);mapped.append({'map':key,'theme':value.get('theme'),'selector':row['selector']})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_function_bytes':{hex(a):len(b) for a,b in p.full.items()},'load_assignment_slice':{'start':'0xfffa8','stop':'0xfffbc','bytes':20,'sha256':hashlib.sha256(p.load_slice).hexdigest(),'supplied_getText_and_map_pointers':True},'original_unchanged':True,'cases':cases,'preserved_imported_maps':mapped}
 Path('tests/fixtures/native-map-theme-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'maps':len(mapped),'original_names':names,'values':{str(x['input']):x['selector'] for x in cases[:3+len(names)]},'unchanged':True}),flush=True)
if __name__=='__main__':main()
