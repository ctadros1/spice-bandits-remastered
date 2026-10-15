"""Bounded original ordinary animator Update and inactive-tower rendering.

Frame metadata/delta/speed/flags are explicit; alpha-animation branch omitted.
Render calls/GL are recorded stubs. Captures preview tint and retained facing,
not original atlas pixels, input callback ordering or a whole original battle.
"""
from native_creep_reference import *
class PreviewProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0x36b2ac:
   self.tint=[struct.unpack('<f',I(u.reg_read(r)))[0] for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]];self.ret();return
  if a in [0x11515c,0x1159c4,0x10f170,0x10f54c,0x10f248]:self.ret();return
  super().hook(u,a,size,data)
 def animation(self,count,speed,loop,steps,multiplier=1,divisor=1):
  self.stop=END;self.u.mem_write(E,bytes(0x2000));self.u.mem_write(E+0x28,I(E+0x1000));self.u.mem_write(E+0x24,F(multiplier));self.u.mem_write(E+0x4c,F(divisor))
  self.u.mem_write(E+0x100c,I(count));self.u.mem_write(E+0x1010,F(speed));self.u.mem_write(E+0x1014,bytes([loop]))
  self.u.mem_write(0x40a26c,I(E+0x1200));self.u.mem_write(0x40a270,I(E+0x1300));frames=[]
  for dt in steps:
   self.u.mem_write(E+0x1300,F(dt));self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E)
   self.u.emu_start(0x10f3a1,END,count=10000);assert self.u.reg_read(UC_ARM_REG_PC)==END
   frames.append({'dt_ms':dt,'frame':struct.unpack('<i',self.u.mem_read(E+0x44,4))[0],'phase':struct.unpack('<f',self.u.mem_read(E+0x64,4))[0],'stopped':bool(self.u.mem_read(E+0x48,1)[0])})
  return frames
 def inactive(self,frame,valid):
  self.stop=END;self.u.mem_write(E,bytes(0x2000));self.u.mem_write(E+0x54,b'\x01');self.u.mem_write(E+0x42,bytes([valid]));self.u.mem_write(E+0x34,F(1));self.u.mem_write(E+0xb4,I(frame));self.u.mem_write(E+0xf0,I(E+0x1000));self.u.mem_write(E+0x1080,b'\x01')
  self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E);self.u.emu_start(0xe8431,END,count=10000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'frame':struct.unpack('<i',self.u.mem_read(E+0x178,4))[0],'angle':struct.unpack('<f',self.u.mem_read(E+0x11c,4))[0],'tint':self.tint}
probe=PreviewProbe();cases=[]
for count,speed,loop in [(40,10,1),(40,25,1),(1,1,1),(26,10,1),(4,25,0)]:
 for multiplier,divisor in [(1,1),(2,1),(1,.5)]:
  for steps in [[30]*150,[1,16.67,100,250,500,1000,5000]]:
   cases.append({'count':count,'speed':speed,'loop':loop,'multiplier':multiplier,'divisor':divisor,'frames':probe.animation(count,speed,loop,steps,multiplier,divisor)})
inactive=[{'frame':f,'valid':v,'output':probe.inactive(f,v)} for f in range(40) for v in [False,True]]
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'animation_cases':cases,'inactive_cases':inactive,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-tower-preview-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'frames':sum(len(c['frames']) for c in cases),'inactive_cases':len(inactive),'original_unchanged':result['original_unchanged']}))
