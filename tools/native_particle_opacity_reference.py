"""Original opacity fields over every authored lifetime/blend/fade combination."""
from native_creep_reference import *
class OpacityProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0x111418:self.ret(1)
  else:super().hook(u,a,size,data)
 def sample(self,life,blend,fade,age):
  u=self.u;s=E;p=E+0x1000;u.mem_write(s,bytes(2048));u.mem_write(p,bytes(100))
  for off,v in [(8,5),(12,life),(0x38,1),(0x3c,1),(0x40,1),(0x44,1),(0x50,1),(0x58,blend),(0x5c,fade),(0xc0,age)]:u.mem_write(s+off,F(v))
  code=bytes(u.mem_read(0x111088,912));u.mem_write(s+0xdc,I(p));u.mem_write(s+0xb8,I(1));self.stop=END
  u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,s);u.reg_write(UC_ARM_REG_R1,BITS(0));u.emu_start(0x111089,END,count=20000);assert u.reg_read(UC_ARM_REG_PC)==END
  assert bytes(u.mem_read(0x111088,912))==code
  return {'opacity_bits':struct.unpack('<I',u.mem_read(p+0x24,4))[0],'rgba_alpha_bits':struct.unpack('<I',u.mem_read(p+0x1c,4))[0]}
def main():
 systems=json.loads(Path('game/data/particles.json').read_text())['systems'];definitions=sorted({(float(d.get('life_cycle',1)),float(d.get('blend_delay',0)),float(d.get('fade_in_time',0))) for d in systems.values()});probe=OpacityProbe();cases=[]
 for life,blend,fade in definitions:
  ages={struct.unpack('<f',F(life*f))[0] for f in [-.1,0,.1,.5,.9,1,1.1]}
  for boundary in [life,fade,life/blend if blend>0 else life]:
   bits=BITS(boundary)
   for delta in [-1,0,1]:
    if bits+delta>=0:ages.add(struct.unpack('<f',I(bits+delta))[0])
  for age in sorted(ages):cases.append({'life':life,'blend':blend,'fade':fade,'age':age,'output':probe.sample(life,blend,fade,age)})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 Path('tests/fixtures/native-particle-opacity-reference.json').write_text(json.dumps({'original_sha256':EXPECTED_SHA,'original_unchanged':True,'original_functions_unchanged':True,'definition_combinations':len(definitions),'cases':cases,'scope':'Full original CParticleSystem.Update opacity and RGBA-alpha fields at supplied zero-dt clocks across every authored life/blend/fade combination plus near-boundary float bits. One supplied particle; Emit is a no-particle success stub. Clock/field math only, not resource parser, complete update callers, GPU or room.'},indent=2)+'\n');print(json.dumps({'cases':len(cases),'combinations':len(definitions),'original_unchanged':True}))
if __name__=='__main__':main()
