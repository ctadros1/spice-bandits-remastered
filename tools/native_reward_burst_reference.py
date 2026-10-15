"""Original WinSpiceBump anchor block0xbaa48..0xbaaf4.

Explicit content dimensions, integer origin, slot and three supplied rand
results. Original getRandomVector and getRandomMinMax execute, using host
float32 sinf/cosf recording stubs. Start after particle allocation; stop after
anchor/interval/clock writes, before speed/Emit. No whole-game RNG or raster.
"""
from native_creep_reference import *
from collections import deque
import ctypes

lib=ctypes.CDLL(None)
for name in ['sinf','cosf']:
 fn=getattr(lib,name);fn.argtypes=[ctypes.c_float];fn.restype=ctypes.c_float

class BurstProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0xbaaf4:u.emu_stop();return
  if a==0x36c7cc:self.ret(self.values.popleft());return
  if a in [0x36c43c,0x36c88c]:
   angle=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0]
   self.ret(BITS((lib.cosf if a==0x36c43c else lib.sinf)(angle)));return
  if a==0xbaa52:self.vector=list(struct.unpack('<2f',u.mem_read(STACK+0xa4,8)))
  if a==0xbaa62:self.radius=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0]
  super().hook(u,a,size,data)
 def run(self,content,index,values):
  self.values=deque(values);self.vector=None;self.radius=None;self.u.mem_write(E,bytes(0x4000));self.u.mem_write(STACK-256,bytes(1024))
  self.u.mem_write(E+0xec,struct.pack('<2i',188,127));self.u.mem_write(E+0x1008,I(E+0x2000));self.u.mem_write(E+0x2008,struct.pack('<2f',*content))
  self.u.reg_write(UC_ARM_REG_SP,STACK)
  for offset,value in [(0x28,E+0x1000),(0x40,E),(0x30,E+0x3000),(0x38,index)]:self.u.mem_write(STACK+offset,I(value))
  for reg,value in [(UC_ARM_REG_D8,6),(UC_ARM_REG_D9,.5)]:self.u.reg_write(reg,struct.unpack('<Q',F(value)*2)[0])
  self.u.emu_start(0xbaa49,0xbaaf4,count=10000);assert self.u.reg_read(UC_ARM_REG_PC)==0xbaaf4 and not self.values
  return {'content':content,'index':index,'rand':values,'vector':self.vector,'radius':self.radius,'point':list(struct.unpack('<2f',self.u.mem_read(E+0x30a0,8))),'interval':struct.unpack('<f',self.u.mem_read(E+0x3008,4))[0],'clock_multiplier':struct.unpack('<f',self.u.mem_read(E+0x3050,4))[0]}

def main():
 p=BurstProbe()
 samples=[(0,0,0),(1,1,1),(0x7fffffff,0x7fffffff,0x7fffffff),(0x40000000,0x40000000,0x40000000),(0x20000000,0x60000000,0x20000000),(0x60000000,0x20000000,0x60000000),(123456789,987654321,135792468),(0x7ffffffe,0x3fffffff,0x40000001)]
 cases=[p.run(content,index,values) for content in [(160,20),(233.5,21),(511,33)] for index in range(7) for values in samples]
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-reward-burst-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
