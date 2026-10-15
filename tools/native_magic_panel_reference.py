"""Execute original iPad magic panel open/close/update with explicit bounds."""
from native_creep_reference import *
class MagicProbe(Probe):
 def hook(self,u,a,size,data):
  if a in [0x36be6c,0x97628]:self.ret(0);return
  super().hook(u,a,size,data)
 def call(self,address,*values):
  self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1],values):self.u.reg_write(r,v)
  self.u.emu_start(address|1,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
 def state(self):
  flags=self.u.mem_read(E+0x40,5)
  return {'y':struct.unpack('<f',self.u.mem_read(E+0x30,4))[0],'phase':struct.unpack('<f',self.u.mem_read(E+0x38,4))[0],**{key:bool(flags[i]) for i,key in enumerate(['visible','opening','closing','opened','hidden'])}}
 def run(self,actions,panel_height):
  self.u.mem_write(E,bytes(128));self.u.mem_write(E+0x28,I(panel_height));self.u.mem_write(E+0x30,F(707));self.u.mem_write(E+0x44,b'\x01')
  addr=struct.unpack('<I',self.u.mem_read(0x40a204,4))[0];self.u.mem_write(addr,I(768))
  frames=[]
  for action in actions:
   if action=='open':self.call(0x9760c,E)
   elif action=='close':self.call(0x97fec,E)
   else:self.call(0x9810c,E,BITS(action))
   frames.append({'action':action,'state':self.state()})
  return frames
probe=MagicProbe();cases=[]
for panel_height in [265,335]:
 for actions in [['open',0,100,150,250,'close',0,125,375],['open',200,'close',100,300,500],['open',600,'close',600,'open',16.667,483.333],['open']+[16.667]*31+['close']+[16.667]*31]:cases.append({'panel_height':panel_height,'frames':probe.run(actions,panel_height)})
result={'source_sha256':EXPECTED_SHA,'method':__doc__,'height':768,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-magic-panel-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
