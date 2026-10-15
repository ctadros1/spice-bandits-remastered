"""Execute only native particle integration/opacity, with emission and sin stubs."""
from native_creep_reference import *
import math
class ParticleProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0x111418:self.ret(1)
  elif a==0x36c88c:self.ret(BITS(math.sin(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0])))
  else:super().hook(u,a,size,data)
 def sample(self,age,dt,blend,fade,wind):
  S=E;P=E+0x1000;u=self.u;u.mem_write(S,bytes(2048));u.mem_write(P,bytes(100));self.stop=END
  for off,value in [(8,1),(12,1.6),(0x28,0),(0x2c,30),(0x38,1),(0x3c,1),(0x40,1),(0x44,.9),(0x50,1),(0x58,blend),(0x5c,fade),(0xc0,age)]:u.mem_write(S+off,F(value))
  u.mem_write(S+0xd4,bytes([wind]));u.mem_write(S+0xdc,I(P));u.mem_write(S+0xb8,I(1))
  for off,value in [(0,100),(4,200),(8,10),(12,-70),(0x20,0),(0x28,.5),(0x2c,3)]:u.mem_write(P+off,F(value))
  u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,S);u.reg_write(UC_ARM_REG_R1,BITS(dt));u.emu_start(0x111089,END,count=10000)
  result={k:struct.unpack('<f',u.mem_read(P+o,4))[0] for k,o in [('x',0),('y',4),('vx',8),('vy',12),('rotation',0x28),('alpha',0x24)]}
  result.update(age=age,dt=dt,blend=blend,fade=fade,wind=wind);return result
p=ParticleProbe();rows=[]
for age in [0,.3,.7,1.2]:
 for dt in [.001,.01667,.03,.033333,.1,.133333,.25,.333333]:
  for blend,fade in [(0,0),(2,0),(0,.8)]:
   for wind in [0,1]:rows.append(p.sample(age,dt,blend,fade,wind))
result={'method':'CParticleSystem::Update0x111088 in bounded ARM execution; one particle, no texture/rendering, Emit returns success without generating, sinf stub available but amplitude zero. Original system structs initialized explicitly. Not an original app replay.','original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':rows}
Path('tests/fixtures/native-particle-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(len(rows),'native particle cases')
