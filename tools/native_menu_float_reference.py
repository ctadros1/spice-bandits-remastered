"""Execute original menu floating-text and lamp declarations.

Objective-C objects/numbers/arrays/layers, path recording, frame height, layer
position, media time and controlled rand values are explicit stubs. The ARM
path/rotation/lamp arithmetic executes; UIKit interpolation/rasterization does not.
"""
from native_menu_animation_reference import *

class FloatProbe(AnimationProbe):
 def hook(self,u,a,size,data):
  if a==0x36cadc:self.ret(u.reg_read(UC_ARM_REG_R0)%u.reg_read(UC_ARM_REG_R1));return
  if a==0x36b65c:
   bits=struct.unpack('<2I',struct.pack('<d',self.media_time));self.ret(bits[0]);u.reg_write(UC_ARM_REG_R1,bits[1]);return
  if a==0x36b07c:self.ret(self.alloc({'points':[]}));return
  if a in (0x36b08c,0x36b06c):
   path,x,y=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R2,UC_ARM_REG_R3)]
   self.objects[path]['points'].append([struct.unpack('<f',I(x))[0],struct.unpack('<f',I(y))[0]]);self.ret();return
  if a==0x36b09c:self.ret();return
  if a==0x36be9c:
   output,receiver,selector=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)]
   if self.string(selector)=='position':u.mem_write(output,struct.pack('<2f',*self.position));self.ret();return
  if a==0x36be6c:
   receiver,selector,arg,r3=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)];name=self.string(selector)
   if name=='view':self.ret(E+0x6000);return
   if name=='frameHeight':self.ret(BITS(self.height));return
   if name=='animationsView':self.ret(E+0x6000);return
   if name=='viewWithTag:':
    target=E+0x7000+(arg-100)*0x100;self.names_by_address[target]='lamp-'+str(arg);self.ret(target);return
   if name=='setPath:':self.objects[receiver]['Path']=self.value(arg);self.ret();return
   if name=='setAdditive:':self.objects[receiver]['Additive']=bool(arg);self.ret();return
   if name=='setBeginTime:':self.objects[receiver]['BeginTime']=struct.unpack('<d',I(arg)+I(r3))[0];self.ret();return
  super().hook(u,a,size,data)
 def floating(self,height,position,random):
  self.prepare(random);self.height=height;self.position=position
  self.names_by_address[E+0x7000]='floating-view';self.u.reg_write(UC_ARM_REG_R2,E+0x7000)
  try:self.u.emu_start(0x1ff61,END,count=100000)
  except UcError:print('float failed',hex(self.u.reg_read(UC_ARM_REG_PC)));raise
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'height':height,'position':position,'random':random,'animations':self.animations}
 def lamps(self,media_time):
  self.prepare();self.media_time=media_time
  self.u.emu_start(0x22299,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'media_time':media_time,'animations':self.animations}

def main():
 p=FloatProbe()
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,
  'floats':[p.floating(h,xy,r) for h in [320,768,1024] for xy in [(0,0),(100.5,200.25)] for r in [(0,0,0,0,0),(1,99,39,39,99),(77,25,10,30,50),(12345,12345,12345,12345,12345)]],
  'lamps':[p.lamps(t) for t in [0,10.5,12345.678]],
  'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-menu-float-reference.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'sample':record['floats'][1],'lamps':record['lamps'][0],'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
