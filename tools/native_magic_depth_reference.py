"""Full original mine/portal constructors and cell/mouse position functions.

Supplied effect/frame heights, animation-play/stop, registration, hex center,
mouse-to-grid and cell callbacks replace resource/map frameworks. Original
constructor/position arithmetic executes; no GPU/input/whole-map lifetime.
"""
import sys
sys.path.insert(0,'tools')
from native_map_order_reference import *
class Magic(OrderProbe):
 def hook(self,u,a,size,data):
  if a==0x10e064:
   name=self.string(u.reg_read(UC_ARM_REG_R0));self.effects.append(name)
   self.ret((E+0x2000 if name=='MineLights' else E+0x1000) if self.animation else 0);return
  if a==0x10f13c:self.ret();return
  if a==0x1034c0:
   self.registered.append({'map':u.reg_read(UC_ARM_REG_R0)-E,'actor':u.reg_read(UC_ARM_REG_R1)-E,'height':struct.unpack('<f',u.mem_read(E+0x14,4))[0]});self.ret();return
  if a==0x109fb4:self.point(u.reg_read(UC_ARM_REG_R1),self.center);self.ret();return
  if a==0x10b8d0:
   u.mem_write(u.reg_read(UC_ARM_REG_R2),I(7));u.mem_write(u.reg_read(UC_ARM_REG_R3),I(4));self.ret();return
  super().hook(u,a,size,data)
 def construct(self,kind,height,animation=True):
  self.reset();self.effects=[];self.registered=[];self.animation=animation
  self.u.mem_write(E+0x1028,I(E+0x3000));self.u.mem_write(E+0x3048,F(height));self.u.mem_write(E+0x5000+0x74,I(E+0x5100));self.u.mem_write(E+0x600c,I(E+0x5000))
  self.invoke(0x9aa2c if kind=='mine' else 0x9bcc4,[E,E+0x5000 if kind=='mine' else E+0x6000,0,0])
  return {'height':struct.unpack('<f',self.u.mem_read(E+0x14,4))[0],'effects':list(self.effects),'registered':list(self.registered),'vtable':struct.unpack('<I',self.u.mem_read(E,4))[0]}
 def position(self,kind,height,center,mouse,light):
  declaration=self.construct(kind,height);self.center=center;self.cell_light=light
  self.invoke((0x9af3c if mouse else 0x9b028) if kind=='mine' else (0x9c4b8 if mouse else 0x9c580),[E,7,4])
  point=lambda off:list(struct.unpack('<2f',self.u.mem_read(E+off,8)))
  return {'declaration':declaration,'point':point(0x4c),'animator':point(0x1000),'top':struct.unpack('<i',self.u.mem_read(E+0xc,4))[0],'light':struct.unpack('<f',self.u.mem_read(E+0x34,4))[0]}
p=Magic();declarations=[];positions=[]
for kind in ['mine','portal']:
 for h in [0,16,40,60,100,87.25]:
  for animation in [False,True]:declarations.append({'kind':kind,'height':h,'animation':animation,'output':p.construct(kind,h,animation)})
  for y in [-100.75,-7.125,0,150,150.875]:
   for mouse in [False,True]:
    for light in [None,.625]:positions.append({'kind':kind,'height':h,'center':[231.25,y],'mouse':mouse,'cell_light':light,'output':p.position(kind,h,[231.25,y],mouse,light)})
Path('tests/fixtures/native-magic-depth-reference.json').write_text(json.dumps({'declarations':declarations,'positions':positions,'method':'Full original mine/portal constructors +cell/mouse position functions; supplied effect/frame height, hexcenter/screentogrid/cell callbacks; animation play/stop/registration stubs. No originalGPU/wholemaplifetime.','source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA},indent=2)+'\n')
print(json.dumps({'declarations':len(declarations),'positions':len(positions),'sample':positions[-1]}))
