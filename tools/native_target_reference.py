"""Run original target selection with supplied creep records and true-range stub."""
from native_creep_reference import *
import itertools
class TargetProbe(Probe):
 def hook(self,u,a,size,data):
  if a in [0xfbd7e,0xfbd88]:u.emu_stop();return
  if a==0xe1afc:
   vector=u.reg_read(UC_ARM_REG_R0);item=u.reg_read(UC_ARM_REG_R1);base,end,cap=struct.unpack('<3I',u.mem_read(vector,12))
   if not base:base=E+0x18000;end=base;cap=base+512
   u.mem_write(end,bytes(u.mem_read(item,4)));u.mem_write(vector,struct.pack('<3I',base,end+4,cap));self.ret()
  elif a==0x122020:self.ret(1 if self.string(u.reg_read(UC_ARM_REG_R0))==self.string(u.reg_read(UC_ARM_REG_R1)) else 0)
  elif a==0x110a30:self.ret(1)
  elif a in [0x36c18c,0x36ca7c]:self.ret()
  else:super().hook(u,a,size,data)
 def sample(self,entries,mode='fastest',gravity=0,aim=0,owner=1,collect=False):
  u=self.u;u.mem_write(E,bytes(0x19000));tower=E+0x1000;res=E+0x2000;lst=E+0x3000;self.stop=END
  u.mem_write(0x47ed54,I(lst));u.mem_write(0x47ed58,I(lst+4*len(entries)))
  circle=struct.unpack('<I',u.mem_read(0x40a288,4))[0];u.mem_write(circle,F(1.44))
  u.mem_write(tower+0x58,I(owner));u.mem_write(res+0x83,bytes([gravity]))
  objects=[]
  for i,row in enumerate(entries):
   p=E+0x4000+1024*i;desc=E+0x10000+16*i;objects.append(p);u.mem_write(lst+4*i,I(p));u.mem_write(p+0x140,F(row.get('hp',10)));u.mem_write(p+0x224,F(row.get('speed',1000)));u.mem_write(p+0x250,I(desc));u.mem_write(desc+4,I(row.get('aim',1)));u.mem_write(p+0x170,bytes([row.get('state',0)]));u.mem_write(p+0x160,I(row.get('owner',0)));u.mem_write(p+0x164,I(row.get('target_owner',0)));self.point(p+0x1e0,row['grid'])
  textaddr=E+0x17000;u.mem_write(textaddr,mode.encode()+b'\0');vector=E+0x17100 if collect else 0
  sp=STACK-64;u.mem_write(sp,struct.pack('<4I',BITS(100),aim,textaddr,vector))
  for reg,val in [(UC_ARM_REG_R0,0),(UC_ARM_REG_R1,0),(UC_ARM_REG_R2,tower),(UC_ARM_REG_R3,res),(UC_ARM_REG_SP,sp),(UC_ARM_REG_LR,END|1)]:u.reg_write(reg,val)
  
  try:u.emu_start(0xfb9b1,END,count=100000)
  except UcError:
   print("PC",hex(u.reg_read(UC_ARM_REG_PC)),"SP",hex(u.reg_read(UC_ARM_REG_SP)),"LR",hex(u.reg_read(UC_ARM_REG_LR)),"native target probe");raise
  selected=u.reg_read(UC_ARM_REG_R4);answer=objects.index(selected) if selected in objects else -1
  if collect:
   start,end,_=struct.unpack('<3I',u.mem_read(vector,12));chosen=[objects.index(struct.unpack('<I',u.mem_read(a,4))[0]) for a in range(start,end,4)] if start else []
  else:chosen=[]
  return {'entries':entries,'mode':mode,'gravity':gravity,'aim':aim,'owner':owner,'collect':collect,'selected':answer,'collected':chosen}
p=TargetProbe();rows=[]
base=[{'grid':[3,0],'hp':20.7,'speed':600},{'grid':[2,0],'hp':20.2,'speed':700},{'grid':[4,0],'hp':100,'speed':900},{'grid':[1,0],'hp':10,'speed':500}]
for order in itertools.permutations(base):
 for mode in ['fastest','strongest','weakest','']:
  rows.append(p.sample(list(order),mode))
for field,values in [('state',[0,1,2,3,4,5,6]),('aim',[1,2]),('owner',[0,1,2]),('target_owner',[0,1,2]),('hp',[0,1])]:
 for value in values:
  entries=[{'grid':[3,0],field:value},{'grid':[2,0],'hp':1,'speed':500}]
  for gravity in [0,1]:rows.append(p.sample(entries,gravity=gravity));rows.append(p.sample(entries,gravity=gravity,collect=True))
result={'method':'Original GetNearestCreep0xfb9b0, configured list, positions, aim/owner/status fields. Ellipse stub returns true for every candidate; vector append and exact string matcher are stubbed. Does not execute creep state changes, source ownership assignment, target retention or rendering. Selection is captured in r4 before temporary-vector cleanup at0xfbd7e/0xfbd88.','original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':rows}
Path('tests/fixtures/native-target-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(len(rows),'native target cases');print(rows[:4])
