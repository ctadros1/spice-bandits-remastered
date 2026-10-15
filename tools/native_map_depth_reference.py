"""Bounded original tower depth declarations, placement and map comparator.

CAnimFrames constructor uses zero frames: string/framework calls are stubs,
not an animation-loader execution. CTower constructor suffix0xe2e3c..0xe2ed6
uses supplied animator/resource/stack records and a GetParam stub. SetPosition
runs fully with supplied cell center/light. Map comparator executes directly.
UpdateParams0xe3c9e..0xe3cbe executes the real animator Init with supplied
animation-group lookup; its cleared current-animation pointer retains the
old tower height. No original map sorting, GPU, services or whole game.
"""
from native_creep_reference import *


class DepthProbe(Probe):
 def reset(self,stop=END):
  self.stop=stop;self.center=(0,0);self.cell_light=None;self.override=None
  self.u.mem_write(E,bytes(0x10000));self.u.mem_write(STACK-0x2000,bytes(0x2000))
  self.u.reg_write(UC_ARM_REG_SP,STACK-0x1000);self.u.reg_write(UC_ARM_REG_LR,END|1)
 def invoke(self,address,args):
  for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(reg,value)
  self.u.emu_start(address|1,self.stop,count=20000)
  assert self.u.reg_read(UC_ARM_REG_PC)==self.stop,hex(self.u.reg_read(UC_ARM_REG_PC))
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==self.stop:u.emu_stop();return
  if a==0x10b614:self.point(r3,self.center);self.ret();return
  if a==0x1066fc:
   if self.cell_light is None:self.ret(0)
   else:u.mem_write(E+0x501c,F(self.cell_light));self.ret(E+0x5000)
   return
  if a==0x11794c:
   if self.string(r1)=='depth_pos' and self.override is not None:
    u.mem_write(E+0x2008,struct.pack('<i',self.override));self.ret(E+0x2000)
   else:self.ret(0)
   return
  if a==0x36c97c:self.ret(len(self.string(r0)));return
  if a==0x11c9a8:self.ret(E+0x7000);return
  if a in [0x36c00c,0x36ca5c,0x36ca7c]:self.ret();return
  super().hook(u,a,size,data)
 def animation_dimensions(self,width,height):
  self.reset();sp=self.u.reg_read(UC_ARM_REG_SP)
  # AAPCS soft-float: this,name,texture,width in R0..R3; height onward on stack.
  args=[BITS(height),0,0,1,1,0,BITS(1),0,0,0,0,0,0,0,0,E+0x3000]
  self.u.mem_write(sp,struct.pack('<16I',*args))
  self.invoke(0x10e424,[E,self.intern('Idle'),E+0x4000,BITS(width)])
  return list(struct.unpack('<2f',self.u.mem_read(E+0x44,8)))
 def tower_declaration(self,height,override=None,resource=True,animation=True):
  self.reset(0xe2ed6);self.override=override;sp=self.u.reg_read(UC_ARM_REG_SP)
  self.u.mem_write(sp+0x38,I(E));self.u.mem_write(sp+0x2c,I(E))
  self.u.reg_write(UC_ARM_REG_R7,E+0x6000);self.u.mem_write(E+0x6008,I(E+0x1000))
  self.u.mem_write(E+0xf0,I(E+0x1000));self.u.mem_write(E+0x108c,I(E+0x3000 if resource else 0))
  self.u.mem_write(E+0x98,I(E+0x4000 if animation else 0));self.u.mem_write(E+0x4048,F(height))
  self.invoke(0xe2e3c,[])
  return struct.unpack('<f',self.u.mem_read(E+0x14,4))[0]
 def position(self,center,height,light=None):
  self.reset();self.center=center;self.cell_light=light
  self.u.mem_write(E+0x14,F(height));self.u.mem_write(E+0x1c,I(E+0x1000));self.u.mem_write(E+0x1074,I(E+0x2000))
  self.u.mem_write(E+0x34,F(1))
  for off in [0x1a8,0x1b0,0x1b4,0x1b8]:self.u.mem_write(E+off,I(E+0x3000+off))
  self.invoke(0xe4228,[E,6,7])
  y=struct.unpack('<i',self.u.mem_read(E+0xc,4))[0]
  return {'center':list(struct.unpack('<2f',self.u.mem_read(E+0x4c,8))),
          'animator':list(struct.unpack('<2f',self.u.mem_read(E+0x70,8))),
          'depth_top':y,'height':struct.unpack('<f',self.u.mem_read(E+0x14,4))[0],
          'light':struct.unpack('<f',self.u.mem_read(E+0x34,4))[0]}
 def compare(self,a,b):
  self.reset()
  for address,value in [(E,a),(E+0x100,b)]:
   self.u.mem_write(address+0xc,struct.pack('<i',value[0]));self.u.mem_write(address+0x14,F(value[1]))
  self.invoke(0x103650,[E,E+0x100]);return bool(self.u.reg_read(UC_ARM_REG_R0))
 def upgrade_height(self,old_height,new_height):
  self.reset(0xe3cbe)
  self.u.mem_write(E+0x14,F(old_height));self.u.mem_write(E+0x98,I(E+0x4000));self.u.mem_write(E+0x4048,F(new_height))
  self.u.reg_write(UC_ARM_REG_R6,E);self.u.reg_write(UC_ARM_REG_R1,self.intern('towers/new-form'))
  self.invoke(0xe3c9e,[])
  return {'height':struct.unpack('<f',self.u.mem_read(E+0x14,4))[0],'current_animation':struct.unpack('<I',self.u.mem_read(E+0x98,4))[0]}


def main():
 p=DepthProbe();dimensions=[];declarations=[];positions=[];comparisons=[];upgrades=[]
 for width,height in [(100,100),(36,40),(25,25),(58,72),(0,0),(63.5,87.25)]:
  dimensions.append({'width':width,'height':height,'output':p.animation_dimensions(width,height)})
 for height in [0,25,40,60,72,100,87.25]:
  for override,resource,animation in [(None,False,True),(None,True,True),(17,True,True),(-3,True,True),(None,False,False)]:
   declarations.append({'height':height,'override':override,'resource':resource,'animation':animation,'output':p.tower_declaration(height,override,resource,animation)})
 for y in [-100.75,-7,-.125,0,7,49.5,150,150.875,16777218]:
  for height in [0,25,40,60,72,100,87.25]:
   for light in [None,.625]:
    center=[231.25,y];positions.append({'center':center,'height':height,'light':light,'output':p.position(center,height,light)})
 values=[[-100,25],[0,0],[0,100],[50,50],[99,0],[100,0],[100,.25],[16777216,0],[16777217,0]]
 for a in values:
  for b in values:comparisons.append({'a':a,'b':b,'output':p.compare(a,b)})
 for old in [0,25,40,60,72,100,87.25]:
  for new in [25,40,100,87.25]:upgrades.append({'old_height':old,'new_height':new,'output':p.upgrade_height(old,new)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'dimensions':dimensions,'declarations':declarations,'positions':positions,'comparisons':comparisons,'upgrades':upgrades,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-map-depth-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({key:len(result[key]) for key in ['dimensions','declarations','positions','comparisons']}))


if __name__=='__main__':main()
