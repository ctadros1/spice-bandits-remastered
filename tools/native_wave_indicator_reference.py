"""Original CreateIndicators ordering/float32 widths with supplied palette.
Palette bits are code-traced from CRoom::LoadCreepsResource0xd02dc;
this probe executes indicator creation, not that Objective-C/resource loader.
"""
from native_creep_reference import *
PALETTE={}
for ids,bits in [([1,15,16,25,26,27,28,29,30],[0,0,0x3f800000,0x3f800000]),([2,3,17,18,19,20,21],[0x3f800000,0,0,0x3f800000]),([4,22,23,24],[0x3f60c49c,0x3f2cac08,0,0x3f800000]),([5,6,7],[0,0x3f1594af,0x3e000000,0x3f800000]),([8],[0,0x3f249ba6,0x3f33afb8,0x3f800000]),([9,12,13,14],[0x3f3cb924,0x3efcfaad,0x3f5fbe77,0x3f800000]),([10],[0x3efcfaad,0x3e86809d,0x3f1f7cee,0x3f800000]),([11],[0x3f800000,0x3f800000,0,0x3f800000])]:
 for id in ids:PALETTE[id]=[struct.unpack('<f',I(b))[0] for b in bits]
class IndicatorProbe(Probe):
 def __init__(self):self.serial=0;self.created=[];super().__init__()
 def hook(self,u,a,size,data):
  if a==0xda048:self.ret(E+0x11000);return
  if a==0x36c1bc:self.serial+=1;self.ret(E+0x12000+self.serial*32);return
  if a==0xf57c4:
   address=struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_R1),4))[0]
   self.created.append(list(struct.unpack('<5f',u.mem_read(address,20))));self.ret();return
  super().hook(u,a,size,data)
 def sample(self,creeps,width):
  self.created=[];self.serial=0;self.u.mem_write(E,bytes(0x100))
  self.u.mem_write(E+0x18,I(E+0x1000)+I(E+0x1000+len(creeps)*4));self.u.mem_write(E+0x1000,struct.pack('<'+'i'*len(creeps),*creeps))
  self.u.mem_write(E+0x5c,I(sum(n!=-1 for n in creeps)))
  # Sorted linked BST has the same lookup semantics as the original std::map.
  self.u.mem_write(E+0x4000,bytes(64));self.u.mem_write(E+0x4008,I(E+0x5000))
  for i,key in enumerate(sorted(PALETTE)):
   addr=E+0x5000+i*64;self.u.mem_write(addr,bytes(64));self.u.mem_write(addr+0xc,I(addr+64 if i+1<len(PALETTE) else 0));self.u.mem_write(addr+0x10,I(key)+struct.pack('<4f',*PALETTE[key]))
  self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,31,width,E+0x4000]):self.u.reg_write(r,v)
  try:self.u.emu_start(0xf55f5,END,count=200000)
  except UcError as error:raise RuntimeError(f"{error}; pc={hex(self.u.reg_read(UC_ARM_REG_PC))}; lr={hex(self.u.reg_read(UC_ARM_REG_LR))}")
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return self.created
probe=IndicatorProbe();cases=[]
for creeps in [[1]*4,[1,3,1,8,0,30],[-1,1,2,3],list(range(31)),[0,0,11,11,11],[8,9,10,14,24,30]]:
 for width in [60,37,80]:cases.append({'creeps':creeps,'width':width,'indicators':probe.sample(creeps,width)})
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'palette':PALETTE,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-wave-indicators.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'indicators':sum(len(c['indicators']) for c in cases),'original_unchanged':result['original_unchanged']}))
