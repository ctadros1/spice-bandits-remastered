"""Original recursive Update branches with supplied records and stubbed sinf."""
from native_particle_child_owner_reference import *
import math
class MotionProbe(ChildProbe):
 def initialize(self,*args):
  super().initialize(*args)
  if args[0]!=E:self.u.mem_write(args[0]+0x54,bytes([self.real_alpha]))
 def hook(self,u,a,size,data):
  if a==0x36c88c:
   x=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0];self.ret(BITS(math.sin(x)))
  else:super().hook(u,a,size,data)
 def snapshot(self):
  state=self.state('step');state['parent_delay_bits']=self.word(E+0xbc);state['parent_release_bits']=self.word(E+0xc4);state['parent_phase_bits']=self.word(E+0xc8);state['parent_rate']=self.word(E+4);state['parent_first_release']=self.u.mem_read(E+0xd6,1)[0]
  for c,ptr in zip(state['children'],self.children):c['release_bits']=self.word(ptr+0xc4);c['rate']=self.word(ptr+4);c['first_release']=self.u.mem_read(ptr+0xd6,1)[0]
  state['particle_fields']=[{'id':a,'velocity_bits':[self.word(a+8),self.word(a+12)],'rotation_bits':self.word(a+0x28),'opacity_bits':self.word(a+0x24),'rgba_bits':[self.word(a+o) for o in [0x10,0x14,0x18,0x1c]]} for a in self.allocations]
  return state
 def sample(self,flag,limit,dt,delay,amplitude,real_alpha,disable=0):
  self.real_alpha=real_alpha;self.__init__();u=self.u
  u.mem_write(E+0x4c,F(disable));u.mem_write(E+0x54,bytes([real_alpha]));u.mem_write(E+0x68,bytes([flag]));u.mem_write(E+0x64,F(limit));u.mem_write(E+0xbc,F(delay));u.mem_write(E+0x94,F(amplitude));u.mem_write(E+0x98,F(10))
  self.call(0x111418,r1=2);frames=[self.snapshot()]
  for i in range(12):self.call(0x111088,r1=BITS(dt));frames.append(self.snapshot())
  assert all(bytes(u.mem_read(a,len(code)))==code for a,code in self.protected.items())
  return {'input':{'motion_limited':flag,'motion_seconds':limit,'dt':dt,'delay':delay,'amplitude':amplitude,'real_alpha':real_alpha,'disable_seconds':disable},'frames':frames}
def main():
 p=MotionProbe.__new__(MotionProbe);cases=[]
 for flag,limit in [(False,0),(True,0),(True,.12)]:
  for dt in [0,.016667,.03,.05,.1]:
   for delay in [0,.05]:
    for amplitude in [0,.8]:
     for alpha in [0,1]:cases.append(p.sample(flag,limit,dt,delay,amplitude,alpha))
 for dt in [.03,.05,.1]:
  for disable in [.09,.18]:cases.append(p.sample(False,0,dt,0,0,0,disable))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'original_sha256':EXPECTED_SHA,'original_unchanged':True,'original_functions_unchanged':True,'cases':cases,'scope':'Full original parent/recursive child Update/Emit on R136 supplied short-life zero-variance records. Motion gate, delay entry/crossing,0/16.667/30/50/100ms, per-particle sine phase and real-alpha fields varied; sinf Python-math-to-f32 stub; resource/new/delete/string/unwind stubs explicit. Release timestamps/linked active+pool order/full particle color-opacity-velocity-rotation bits recorded. No authored resource parser, wind/random variations, room/GPU or game integration.'}
 Path('tests/fixtures/native-particle-child-motion-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'original_unchanged':True}))
if __name__=='__main__':main()
