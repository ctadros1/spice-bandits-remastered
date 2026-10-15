"""Original CBolt::Construct0xdd1e4 through point generation0xdd376.

Clear, allocations and point-vector insertion are recording stubs. Supplied
rand values execute original getRandomVector with host sinf/cosf; explicit
scatter flags, seven points and10px spread replace caller state. Stops before
segment/ribbon construction. No whole-game RNG, sound, renderer or caller.
"""
from native_creep_reference import *
from native_reward_burst_reference import lib
from collections import deque
import random

class ConstructProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0xdd376:u.emu_stop();return
  if a==0xdd64c:self.ret();return
  if a in [0x36c1bc,0x36c1ac]:
   self.heap+=0x200;self.ret(self.heap);return
  if a==0xddebc:
   ptr=struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_R1),4))[0]
   self.points.append(list(struct.unpack('<2f',u.mem_read(ptr,8))));self.ret();return
  if a==0x36c7cc:self.ret(self.values.popleft());return
  if a in [0x36c43c,0x36c88c]:
   angle=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0]
   self.ret(BITS((lib.cosf if a==0x36c43c else lib.sinf)(angle)));return
  if a in [0xdd26e,0xdd330]:
   address=u.reg_read(UC_ARM_REG_SP)+(0x34 if a==0xdd26e else 0x2c)
   self.vectors.append(list(struct.unpack('<2f',u.mem_read(address,8))))
  super().hook(u,a,size,data)
 def run(self,start,end,values,scatter):
  self.u.mem_write(E,bytes(0x8000));self.points=[];self.vectors=[];self.values=deque(values);self.heap=E+0x2000
  self.point(E+0x1000,start);self.point(E+0x1100,end);self.u.mem_write(E+0x28,I(7));self.u.mem_write(E+0x2c,F(10));self.u.mem_write(E+0x6c,bytes([int(scatter)]))
  self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2],[E,E+0x1000,E+0x1100]):self.u.reg_write(reg,value)
  self.u.emu_start(0xdd1e5,0xdd376,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==0xdd376 and not self.values and len(self.points)==7
  return {'start':start,'end':end,'rand':values,'scatter':scatter,'vectors':self.vectors,'points':self.points}

def main():
 p=ConstructProbe();cases=[]
 for start,end in [((0,0),(120,0)),((12.5,-9.25),(410.25,275.5)),((1000000,-1000000),(1000012,-999997)),((5,5),(5.5,5.25)),((10,20),(10,20))]:
  for seed in [0,1,114,123456]:
   for scatter in [False,True]:
    rng=random.Random(seed);count=12 if scatter else 10
    values=[0]*count if seed==0 else [0x40000000]*count if seed==1 else [rng.randrange(0x80000000) for _ in range(count)]
    cases.append(p.run(start,end,values,scatter))
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-bolt-construct-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'points':sum(len(c['points']) for c in cases),'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
