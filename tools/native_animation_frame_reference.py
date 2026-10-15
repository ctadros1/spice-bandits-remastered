"""Full original CAnimFrames.AddFrame with supplied atlas/group records.
Allocation returns reserved zeroed storage; vector push records its pointer.
No XML loader, texture loader, RenderFrameQuad/GPU or whole game executes.
"""
from native_map_depth_reference import *
class Frames(DepthProbe):
 def hook(self,u,a,size,data):
  if a==0x36c1bc:self.ret(E+0x8000);return
  if a==0x10f750:
   self.pushed=struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_R1),4))[0];self.ret();return
  super().hook(u,a,size,data)
 def frame(self,group,offset,size,rotation,flip):
  self.reset();self.pushed=None;self.point(E+0x18,group);self.u.mem_write(E+0x4000,bytes(0x30));self.u.mem_write(E+0x4010,struct.pack('<2i',1024,2048));self.point(E+0x3000,(7,-3))
  self.u.mem_write(E+0x8000,bytes(0x48));sp=self.u.reg_read(UC_ARM_REG_SP)
  self.u.mem_write(sp,struct.pack('<8I',BITS(offset[0]),BITS(offset[1]),E+0x3000,BITS(size[0]),BITS(size[1]),flip[0],flip[1],rotation))
  self.invoke(0x10eb58,[E,E+0x4000,26,70]);assert self.pushed==E+0x8000
  return {'uv':list(struct.unpack('<4f',self.u.mem_read(self.pushed,16))),'offset':list(struct.unpack('<2f',self.u.mem_read(self.pushed+0x18,8))),'center':list(struct.unpack('<2f',self.u.mem_read(self.pushed+0x20,8))),'atlas_xy':list(struct.unpack('<2i',self.u.mem_read(self.pushed+0x2c,8))),'size':list(struct.unpack('<2f',self.u.mem_read(self.pushed+0x34,8))),'fliph':self.u.mem_read(self.pushed+0x14,1)[0],'flipv':self.u.mem_read(self.pushed+0x15,1)[0],'rotated':self.u.mem_read(self.pushed+0x28,1)[0]}
def main():
 p=Frames();cases=[]
 for group in [(0,0),(1,14),(-4,-4)]:
  for offset in [(0,0),(2.25,-3.5)]:
   for size in [(1,1),(6,8),(5,7),(70,91)]:
    for rotation in [False,True]:
     for flip in [(False,False),(True,False),(False,True),(True,True)]:
      inp=dict(group=group,offset=offset,size=size,rotation=rotation,flip=flip);cases.append({'input':inp,'output':p.frame(**inp)})
 x={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA};Path('tests/fixtures/native-animation-frame-reference.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':x['original_unchanged']}));print(json.dumps(cases[64]))
if __name__=='__main__':main()
