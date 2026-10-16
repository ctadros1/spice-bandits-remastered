from pathlib import Path
import sys,json,struct,hashlib
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_reference import *
class FactoryProbe(Probe):
 def word(self,a):return struct.unpack('<I',self.u.mem_read(a,4))[0]
 def hook(self,u,a,size,data):
  r0,r1,r2=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a==0x36c04c:u.mem_write(r0,I(r1));self.ret()
  elif a==0x114140:self.ret(E+0x3000 if self.found else 0x47eddc)
  elif a==0x114030:self.ret(E+0x3500)
  elif a==0x36c1bc:
   assert r0==0x10c;self.allocations+=1;u.mem_write(E+0x4000,b'\xcc'*0x200);self.ret(E+0x4000)
  elif a==0x36c6cc:u.mem_write(r0,bytes([r1&255])*r2);self.ret(r0)
  elif a==0x36c6ac:u.mem_write(r0,bytes(u.mem_read(r1,r2)));self.ret(r0)
  elif a==0x36c01c:u.mem_write(r0,I(self.word(r1)));self.ret(r0)
  elif a==0x1262cc:self.ret(self.homogeneous)
  elif a in [0x36c06c,0x36ca5c,0x36ca7c]:self.ret()
  else:super().hook(u,a,size,data)
 def sample(self,found,texture,homogeneous,uv_list,child_name,info):
  self.found=found;self.homogeneous=homogeneous;self.allocations=0;u=self.u
  u.mem_write(E,bytes(0x10000));name=E+0x1000;child=E+0x1100;record=E+0x2000
  for address,text in [(name,'Creep1ExplosionParts'),(child,child_name)]:u.mem_write(address-12,I(len(text))+I(len(text))+I(0));u.mem_write(address,text.encode()+b'\0')
  header=bytearray(0x9c)
  for off,v in [(0,50),(4,6)]:header[off:off+4]=I(v)
  for off,v in [(8,.3),(12,1.3),(0x10,8),(0x18,0),(0x2c,30),(0x38,1),(0x3c,1),(0x40,1),(0x44,1),(0x4c,.5),(0x50,1),(0x58,2)]:header[off:off+4]=F(v)
  u.mem_write(record,bytes(header));u.mem_write(record+0x9c,I(E+0x5000 if texture else 0));u.mem_write(record+0xac,I(E+0x6000 if uv_list else 0));u.mem_write(record+0xb0,I(E+0x6004 if uv_list else 0));u.mem_write(record+0xb8,I(child));u.mem_write(E+0x3500,I(record))
  protected={a:bytes(u.mem_read(a,size)) for a,size in [(0x113d9c,360),(0x110e20,236)]}
  self.stop=END;u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,name);u.reg_write(UC_ARM_REG_R1,E+0x7000 if info else 0)
  u.emu_start(0x113d9d,END,count=100000);assert u.reg_read(UC_ARM_REG_PC)==END
  assert all(bytes(u.mem_read(a,len(code)))==code for a,code in protected.items())
  result=u.reg_read(UC_ARM_REG_R0);output={'returned':result,'allocations':self.allocations}
  if result:
   assert bytes(u.mem_read(result,0x9c))==bytes(header)
   output.update(header_exact=True,active=self.word(result+0xb8),clock_bits=self.word(result+0xc0),release_bits=self.word(result+0xc4),delay_bits=self.word(result+0xbc),backup_rate=self.word(result+0xb0),wind_flag=u.mem_read(result+0xd4,1)[0],homogeneous_flag=u.mem_read(result+0xd5,1)[0],first_release_flag=u.mem_read(result+0xd6,1)[0],active_head=self.word(result+0xdc),pool_head=self.word(result+0xe0),texture=self.word(result+0xe4),info=self.word(result+0xfc),child_string=self.word(result+0x100),texture_sequence=self.word(result+0x104),texture_list=self.word(result+0x108))
  return {'input':{'found':found,'texture':texture,'homogeneous':homogeneous,'uv_list':uv_list,'child_name':child_name,'info':info},'output':output}
def main():
 p=FactoryProbe();rows=[]
 for found in [False,True]:
  for texture in [False,True]:
   for homogeneous in [False,True]:
    for uv_list in [False,True]:
     for child in ['', 'Creep1DebrisSmoke']:
      for info in [False,True]:rows.append(p.sample(found,texture,homogeneous,uv_list,child,info))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 Path('tests/fixtures/native-particle-factory-reference.json').write_text(json.dumps({'cases':rows,'original_sha256':EXPECTED_SHA,'original_functions_unchanged':True,'original_unchanged':True,'scope':'Full original GetNewParticleSystem/C2 on supplied resource header; map/string/new/memcpy/memset/texture/unwind stubs explicit. Header copy/live clock/count/list/pointer initialization; no original resource parser, GPU or game execution.'},indent=2)+'\n');print('factory cases',len(rows))

if __name__=="__main__":main()
