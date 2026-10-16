from pathlib import Path
import sys,struct,json,math,hashlib
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_reference import *
class RenderProbe(Probe):
 def __init__(self):
  super().__init__();self.events=[]
 def hook(self,u,a,size,data):
  if a in [0x36c43c,0x36c88c]:
   x=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0];self.ret(BITS(math.cos(x) if a==0x36c43c else math.sin(x)))
  elif a==0x110524:self.ret(BITS(0))
  elif a==0x111c64:
   self.events.append({'system':u.reg_read(UC_ARM_REG_R1),'particle':u.reg_read(UC_ARM_REG_R2),'base_size_bits':self.word(u.reg_read(UC_ARM_REG_SP))})
  else:super().hook(u,a,size,data)
 def word(self,a):return struct.unpack('<I',self.u.mem_read(a,4))[0]
 def sample(self,real_alpha,homogeneous,opacity,pose):
  u=self.u;root=E;child=E+0x2000;parent=E+0x1000;one=E+0x3000;two=E+0x3100;tex=E+0x4000;count=E+0x4800
  u.mem_write(E,bytes(0x10000));self.events=[]
  for s,size in [(root,2),(child,3)]:u.mem_write(s+0x10,F(size));u.mem_write(s+0xc,F(2));u.mem_write(s+0xc0,F(.375))
  u.mem_write(root+0xd5,bytes([homogeneous]));u.mem_write(root+0xe8,I(E+0x6000));u.mem_write(root+0xf0,I(E+0x8000))
  u.mem_write(child+0x54,bytes([real_alpha]));u.mem_write(child+0xdc,I(one));u.mem_write(parent+0x3c,I(child));u.mem_write(one+0x38,I(two))
  for off,v in [(8,8),(12,6)]:u.mem_write(tex+off,I(v))
  for off,v in [(0x44,.125),(0x48,.375),(0x4c,.25),(0x50,.75)]:u.mem_write(tex+off,F(v))
  for p,point,rgba,opacity in [(parent,(100.25,200.75),(.91,.82,.73,.64),opacity),(one,(103.5,204.25),(.8,.6,.4,.9),.75),(two,(107,200),(.3,.5,.7,.8),.625)]:
   self.point(p,point);u.mem_write(p+0x34,I(tex));u.mem_write(p+0x24,F(opacity))
   for off,v in zip([0x10,0x14,0x18,0x1c],rgba):u.mem_write(p+off,F(v))
  if pose in ['scaled','real-size','mixed']:
   for address,scale,clock in [(root,.4,.375),(child,3,.75)]:
    u.mem_write(address+0x1c,bytes([1]));u.mem_write(address+0x18,F(scale));u.mem_write(address+0xc0,F(clock));u.mem_write(address+0x14,F(.5))
   for address in [parent,one,two]:u.mem_write(address+0x20,F(.125));u.mem_write(address+0x30,F(.125))
  if pose in ['real-size','mixed']:
   u.mem_write(root+0x60,bytes([1]));u.mem_write(child+0x60,bytes([1]))
  if pose=='rotated':
   u.mem_write(root+0x69,bytes([1]));u.mem_write(child+0x69,bytes([1]))
   for address,angle in [(parent,.137),(one,-.333),(two,.7)]:u.mem_write(address+0x28,F(angle))
  if pose=='mixed':
   u.mem_write(root+0x61,bytes([1]));u.mem_write(child+0x69,bytes([1]));u.mem_write(root+0x1c,bytes([0]))
  if pose=='range':
   for off,v in zip([0x10,0x14,0x18,0x1c],[-.1,1.25,1,.64]):u.mem_write(parent+off,F(v))
  def system_record(address):
   return {'definition':{'size':struct.unpack('<f',u.mem_read(address+0x10,4))[0],'size_init_var':struct.unpack('<f',u.mem_read(address+0x14,4))[0],'scale':struct.unpack('<f',u.mem_read(address+0x18,4))[0],'scalable':bool(u.mem_read(address+0x1c,1)[0]),'use_real_size':bool(u.mem_read(address+0x60,1)[0]),'orient_to_velocity':bool(u.mem_read(address+0x61,1)[0]),'rotational':bool(u.mem_read(address+0x69,1)[0]),'real_alpha':bool(u.mem_read(address+0x54,1)[0]),'life_cycle':struct.unpack('<f',u.mem_read(address+12,4))[0]},'clock_seconds':struct.unpack('<f',u.mem_read(address+0xc0,4))[0]}
  def particle_record(address):
   return {'pos':list(struct.unpack('<2f',u.mem_read(address,8))),'rgba':list(struct.unpack('<4f',u.mem_read(address+0x10,16))),'alpha':struct.unpack('<f',u.mem_read(address+0x24,4))[0],'born_seconds':struct.unpack('<f',u.mem_read(address+0x20,4))[0],'rotation':struct.unpack('<f',u.mem_read(address+0x28,4))[0],'size_offset':struct.unpack('<f',u.mem_read(address+0x30,4))[0],'texture':{'width':8,'height':6,'uv':[.125,.375,.25,.75]},'direction_angle':0.0}
  parent_record=system_record(root);child_record=system_record(child)
  parent_record['particles']=[particle_record(parent)];child_record['particles']=[particle_record(one),particle_record(two)];parent_record['particles'][0]['child']=child_record
  initial=parent_record
  protected={a:bytes(u.mem_read(a,size)) for a,size in [(0x111c64,1040),(0x112074,156),(0x112110,212)]}
  outputs=[]
  for render in range(2):
   u.mem_write(count,I(0));u.reg_write(UC_ARM_REG_SP,STACK-16);u.mem_write(STACK-16,F(2));u.reg_write(UC_ARM_REG_LR,END|1)
   for reg,v in [(UC_ARM_REG_R0,root),(UC_ARM_REG_R1,root),(UC_ARM_REG_R2,parent),(UC_ARM_REG_R3,count)]:u.reg_write(reg,v)
   u.emu_start(0x111c65,END,count=200000);assert u.reg_read(UC_ARM_REG_PC)==END
   n=self.word(count);stride=12 if homogeneous else 20;base=E+0x6000 if homogeneous else E+0x8000
   vertices=[]
   for i in range(n):
    raw=bytes(u.mem_read(base+i*stride,stride));vertices.append({'position_bits':list(struct.unpack('<2I',raw[:8])),'uv_bits':list(struct.unpack('<2I',raw[8:16])) if not homogeneous else None,'rgba8':list(raw[-4:])})
   outputs.append({'render':render,'count':n,'vertices':vertices,'child_rgba_bits':[[self.word(p+off) for off in [0x10,0x14,0x18,0x1c]] for p in [one,two]],'events':self.events.copy()});self.events=[]
  assert all(bytes(u.mem_read(a,len(code)))==code for a,code in protected.items())
  return {'real_alpha':real_alpha,'homogeneous':homogeneous,'opacity':opacity,'pose':pose,'input':initial,'outputs':outputs}
def main():
 p=RenderProbe();cases=[p.sample(a,h,opacity,pose) for a in [0,1] for h in [0,1] for opacity in [0,.25,.5,1] for pose in ['plain','scaled','real-size','rotated','mixed','range']]
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 record={'original_sha256':EXPECTED_SHA,'original_unchanged':True,'original_functions_unchanged':True,'cases':cases,'scope':'Full original recursive FillBuffers and actual short/float packing, supplied one parent/two children/texture descriptor. Two held renders per case; scalar sin/cos are Python-math-to-f32 stubs and AngPos explicitly returns0 for oriented cases. Exact geometry/UV/RGBA8 and in-place child RGBA bits recorded. No GPU, actual atlas allocation, original resource parser, room/culling or game port.'}
 Path('tests/fixtures/native-particle-child-render-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'renders':len(cases)*2,'original_unchanged':True}))
if __name__=='__main__':main()
