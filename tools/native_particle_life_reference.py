"""Original float32 particle expiry boundaries; no whole-game replay."""
from native_creep_reference import *
import math

class LifeProbe(Probe):
 def hook(self,u,address,size,data):
  if address==0x111418:self.ret(1) # Emit succeeds without creating particles.
  elif address==0x36c88c:self.ret(BITS(math.sin(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0])))
  else:super().hook(u,address,size,data)
 def sample(self,life,age_bits):
  system=E;particle=E+0x1000;u=self.u
  u.mem_write(system,bytes(2048));u.mem_write(particle,bytes(100));self.stop=END
  for offset,value in [(8,1),(12,life),(0x28,0),(0x2c,30),(0x38,1),(0x3c,1),(0x40,1),(0x44,.9),(0x50,1),(0x58,0),(0x5c,0)]:u.mem_write(system+offset,F(value))
  u.mem_write(system+0xc0,I(age_bits));u.mem_write(system+0xd4,bytes([0]));u.mem_write(system+0xdc,I(particle));u.mem_write(system+0xb8,I(1))
  for offset,value in [(0,100),(4,200),(8,10),(12,-70),(0x20,0),(0x28,.5),(0x2c,3)]:u.mem_write(particle+offset,F(value))
  u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,system);u.reg_write(UC_ARM_REG_R1,BITS(0));u.emu_start(0x111089,END,count=10000)
  return {'active':struct.unpack('<I',u.mem_read(system+0xb8,4))[0],'clock_bits':struct.unpack('<I',u.mem_read(system+0xc0,4))[0]}

def main():
 content=Path('game/data/particles.json');systems=json.loads(content.read_text())['systems'];representatives={}
 for name,d in sorted(systems.items()):representatives.setdefault(float(d.get('life_cycle',1)),name)
 probe=LifeProbe();rows=[]
 for life,name in sorted(representatives.items()):
  life_bits=BITS(life)
  for delta in [-1,0,1]:
   age_bits=life_bits+delta
   rows.append({'system':name,'life':life,'life_bits':life_bits,'age_bits':age_bits,'output':probe.sample(life,age_bits)})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 record={'original_sha256':EXPECTED_SHA,'original_unchanged':True,'content_sha256':hashlib.sha256(content.read_bytes()).hexdigest(),'distinct_authored_lifetimes':len(representatives),'cases':rows,'scope':'Original CParticleSystem.Update0x111088, supplied one-particle system, zero birth, dt0 and clocks one float32 bit below/exactly/above each authored life. Emit returns success without creating; sinf stub available but amplitude zero. Active count and clock bits recorded. No whole room, child ownership, texture/GPU or original resource parsing executes. All original files unchanged.'}
 Path('tests/fixtures/native-particle-life-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(rows),'distinct_lifetimes':len(representatives),'original_unchanged':True}))
if __name__=='__main__':main()
