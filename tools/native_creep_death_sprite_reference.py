"""Original splash creation/DoOnDying/Sprite.Update/Sprite.Render sequence.
Preserved creep1..10 resource parameters and actual PNG dimensions supplied.
Native resource/particle/sound/decal creation uses Effects recording stubs.
Actual Creep.SetDie, Sprite constructor, DoOnDying, Sprite.Update/interpolation
and Sprite.Render execute; final GL/quad submission is recorded. No GPU,
full particle/culling/lifetime/room/global RNG or complete game executes.
"""
import sys,json
sys.path.insert(0,'tools')
from native_creep_death_effects_reference import *
class Sprites(Effects):
 def hook(self,u,a,size,data):
  regs=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==0x36b2ac:self.rgba=regs;self.ret();return
  if a==0x1162c8:
   sp=u.reg_read(UC_ARM_REG_SP);self.draws.append({'rgba_bits':list(self.rgba),'position_bits':regs[1:3],'rotation_bits':regs[3],'size_bits':list(struct.unpack('<2I',u.mem_read(sp,8)))});self.ret();return
  super().hook(u,a,size,data)
 def prepare(self,name):
  result=self.run_effects(name,0,False,[320.25,230.75],[3.5,-7.25],[333.25,219.75],[330.5,220.5])
  for key,texture in self.textures.items():
   file=Path('game')/self.animations[name]['textures'][key]['texture'];w,h=struct.unpack('>2I',file.read_bytes()[16:24]);u=self.u;u.mem_write(texture+4,I(E+0x68000));u.mem_write(E+0x68000,I(1));u.mem_write(texture+8,struct.pack('<2I',w,h));u.mem_write(texture+0x44,struct.pack('<4f',0,1,0,1))
  return result
 def read_sprite(self):
  u=self.u;start,end=struct.unpack('<2I',u.mem_read(E+0x284,8));out=[];self.draws=[];self.rgba=[]
  for a in range(start,end,4):
   p=struct.unpack('<I',u.mem_read(a,4))[0];bits=lambda off,n:list(struct.unpack('<'+'I'*n,u.mem_read(p+off,4*n)))
   out.append({'life_bits':bits(8,1)[0],'position_bits':bits(0x14,2),'scale_bits':bits(0x24,2),'initial_scale_bits':bits(0x2c,2),'rgba_bits':bits(0x34,4)})
   self.invoke(0x121648,[p])
  return {'state':u.mem_read(E+0x170,1)[0],'sprites':out,'draws':self.draws}
def main():
 p=Sprites();p.animations=json.loads(Path('game/data/animations.json').read_text());particles=json.loads(Path('game/data/particles.json').read_text());p.bindings=particles['bindings'];p.systems=particles['systems'];cases=[]
 for i in range(1,11):
  name='creeps/creep'+str(i);creation=p.prepare(name);rows=[{'dt_ms':None,'output':p.read_sprite()}]
  for dt in [0,16.667,30,30,60,100,63.333,1,1]:
   p.invoke(0x7beb8,[E,BITS(dt)]);rows.append({'dt_ms':dt,'output':p.read_sprite()})
  cases.append({'resource':name,'creation':creation,'frames':rows})
 data={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-death-sprite-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'source_unchanged':data['original_unchanged'],'first_frames':cases[0]['frames'][:3]}))

if __name__=="__main__":main()
