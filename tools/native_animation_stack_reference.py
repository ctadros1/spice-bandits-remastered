"""Original AddFrameStack through0x10eaf2 after insertion and frame count.
Allocation/vector insertion/deallocation are bounded reserved-storage stubs;
all frame UV/offset/atlas writes, wrapping and reversal execute original code.
Unwind/temporary-vector cleanup is outside this prefix: Unicorn returns to
address0 through the predicated deallocation BLX import hook. No frame
write or generation/reversal loop is skipped. XML/texture/GPU are omitted.
"""
from native_animation_frame_reference import *
class Stack(Frames):
 def hook(self,u,a,size,data):
  if a==0x36c1bc:
   self.trace.append(("alloc",u.reg_read(UC_ARM_REG_R0)));self.allocations+=1;assert self.allocations<=16;self.ret(E+0x8000+self.allocations*0x100);return
  if a==0x10f750:
   self.trace.append(("push",u.reg_read(UC_ARM_REG_R0),u.reg_read(UC_ARM_REG_R1)));self.vector=u.reg_read(UC_ARM_REG_R0);vector=u.reg_read(UC_ARM_REG_R0);source=u.reg_read(UC_ARM_REG_R1);frame=struct.unpack('<I',u.mem_read(source,4))[0]
   begin=E+0xc000;self.temporary.append(frame);u.mem_write(begin+(len(self.temporary)-1)*4,I(frame));u.mem_write(vector,struct.pack('<3I',begin,begin+len(self.temporary)*4,begin+64));self.ret();return
  if a==0x10f778:
   self.trace.append(("insert",u.reg_read(UC_ARM_REG_R0),u.reg_read(UC_ARM_REG_R1),u.reg_read(UC_ARM_REG_R2),u.reg_read(UC_ARM_REG_R3)));begin=u.reg_read(UC_ARM_REG_R2);end=u.reg_read(UC_ARM_REG_R3);self.frames=list(struct.unpack('<'+'I'*((end-begin)//4),u.mem_read(begin,end-begin)));self.ret();return
  if a==0x36c18c:self.ret();return
  super().hook(u,a,size,data)
 def stack(self,size,offset,x,reverse,flip):
  self.reset(0x10eaf2);self.trace=[];self.allocations=0;self.temporary=[];self.frames=[];self.u.mem_write(E+0x8000,bytes(0x4000));self.point(E+0x44,size);self.point(E+0x18,(19,-8));self.u.mem_write(E+0x4010,struct.pack('<2i',1024,256));sp=self.u.reg_read(UC_ARM_REG_SP)
  self.u.mem_write(sp,struct.pack('<5I',3,reverse,flip,BITS(offset[0]),BITS(offset[1])));
  try:self.invoke(0x10e8d0,[E,E+0x4000,x,4])
  except UcError as error:raise RuntimeError((hex(self.u.reg_read(UC_ARM_REG_PC)),hex(self.u.reg_read(UC_ARM_REG_LR)),self.trace)) from error
  assert len(self.frames)==3
  return [{'offset':list(struct.unpack('<2f',self.u.mem_read(f+0x18,8))),'atlas_bytes':list(struct.unpack('<2I',self.u.mem_read(f+0x2c,8))),'uv':list(struct.unpack('<4f',self.u.mem_read(f,16))),'size':list(struct.unpack('<2f',self.u.mem_read(f+0x34,8)))} for f in self.frames]
def main():
 p=Stack();cases=[]
 for size in [(1,1),(5,7),(64,64),(70,91)]:
  for offset in [(0,0),(2.25,-3.5)]:
   for x in [0,128,192]:
    for reverse in [False,True]:
     for flip in [False,True]:
      source=dict(size=size,offset=offset,x=x,reverse=reverse,flip=flip);cases.append({'input':source,'output':p.stack(**source)})
 x={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA};Path('tests/fixtures/native-animation-stack-reference.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['output']) for c in cases),'original_unchanged':x['original_unchanged']}));print(cases[0])
if __name__=='__main__':main()
