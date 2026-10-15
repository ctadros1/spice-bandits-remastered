"""Execute original particle Update with result clock multiplier1.6.

Uses explicit fields, one particle, zero emission, no render or global RNG.
The existing default-clock fixture is regenerated unchanged by the import.
"""
from native_particle_reference import ParticleProbe,F,E,UC_ARM_REG_R0,struct,Path,json,hashlib,EXE,EXPECTED_SHA
class RewardParticleProbe(ParticleProbe):
 def hook(self,u,a,size,data):
  if a==0x111088:
   system=u.reg_read(UC_ARM_REG_R0);u.mem_write(system+0x50,F(1.6));u.mem_write(system+12,F(self.life))
  super().hook(u,a,size,data)
p=RewardParticleProbe();cases=[]
for life in [1.3,1.6]:
 p.life=life
 for age in [0,.3,.7]:
  for elapsed_ms in [1,16.67,30,33.333,100,133.333,250,333.333]:
   f32=lambda n:struct.unpack('<f',F(n))[0]
   dt=f32(f32(elapsed_ms)*f32(.001))
   for wind in [0,1]:
    case=p.sample(age,dt,0,0,wind)
    case.update(life=life,elapsed_ms=elapsed_ms,clock=struct.unpack('<f',p.u.mem_read(E+0xc0,4))[0]);cases.append(case)
result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-reward-particle-reference.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'original_unchanged':result['original_unchanged']}))
