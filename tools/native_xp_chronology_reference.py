"""Original XP emitter chronology with supplied bar tips/resource fields.

Full WinLose Update and particle constructor/Update/Emit execute. The
result Render emitter block0xbb316..0xbb3c4 executes with supplied tips.
Factory returns the prepared system; malloc/rand0/trig/GPU are explicit
stubs. No complete Open, resource loader, global RNG or device pixels.
"""
import sys,math
sys.path.insert(0,'tools')
from native_result_lifecycle_reference import Room
from native_creep_reference import *
S=E+0x5000
class XP(Room):
 def __init__(self):
  self.frame_events=[];self.alloc=E+0x50000
  super().__init__()
 def hook(self,u,a,size,data):
  if a==0x111834:self.frame_events.append({'method':'factory'});self.ret(S);return
  if a==0x111088:self.frame_events.append({'method':'particle-update','release_count':struct.unpack('<I',u.mem_read(S+4,4))[0]})
  if a==0x111418:self.frame_events.append({'method':'emit','count':u.reg_read(UC_ARM_REG_R1),'point':list(struct.unpack('<2f',u.mem_read(S+0xa0,8)))})
  if a==0x111880:self.frame_events.append({'method':'particle-render','active':struct.unpack('<I',u.mem_read(S+0xb8,4))[0]});self.ret();return
  if a==0x36c1bc:
   p=self.alloc;self.alloc+=0x100;u.mem_write(p,bytes(0x100));self.ret(p);return
  if a==0x36c7cc:self.ret(0);return
  if a==0x36cafc:
   denominator=u.reg_read(UC_ARM_REG_R1);assert denominator
   self.ret(u.reg_read(UC_ARM_REG_R0)%denominator);return
  if a in [0x36c43c,0x36c88c]:
   angle=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0];self.ret(BITS((math.cos if a==0x36c43c else math.sin)(angle)));return
  super().hook(u,a,size,data)
 def render_tip(self,x):
  self.u.mem_write(E+0x98,F(x));self.u.reg_write(UC_ARM_REG_R4,E);self.u.reg_write(UC_ARM_REG_S0,BITS(x));self.u.reg_write(UC_ARM_REG_SP,STACK-0x1000);self.u.reg_write(UC_ARM_REG_LR,END|1)
  self.stop=0xbb3c4
  self.u.emu_start(0xbb317,self.stop,count=10000)
  assert self.u.reg_read(UC_ARM_REG_PC)==self.stop
  self.stop=END
 def sample(self,dt,frames,pattern="normal"):
  self.u.mem_write(E,bytes(0x80000));self.alloc=E+0x50000
  for address,p,value in [(0x40a20c,E+0x2000,1024),(0x40a204,E+0x2004,768),(0x40a1d8,E+0x6800,0)]:self.u.mem_write(address,I(p));self.u.mem_write(p,I(value))
  self.invoke(0xb959c,[E,E+0x4000]);self.invoke(0x110e20,[S,E+0x8000])
  for offset,value in [(8,.03),(12,1.7),(0x48,0)]:self.u.mem_write(S+offset,F(value))
  self.u.mem_write(S,I(100));self.u.mem_write(S+0x108,I(E+0x6500));self.u.mem_write(E+0x6500,struct.pack('<2I',E+0x6600,E+0x6604));self.u.mem_write(E+0x6600,I(E+0x6700))
  self.u.mem_write(E,I(1));self.u.mem_write(E+0x9c,b'\x01');self.u.mem_write(E+0xa0,F(3));self.u.mem_write(E+0x94,F(522));self.u.mem_write(E+0x98,F(522));self.u.mem_write(E+0x4c,I(E+0x6900));self.u.mem_write(E+0x690c,I(24));self.u.mem_write(E+0xf0,I(127))
  output=[]
  for i in range(frames):
   self.frame_events=[];self.invoke(0xbc08c,[E,BITS(dt)]);phase=struct.unpack('<f',self.u.mem_read(E+0xa4,4))[0]
   x=struct.unpack('<f',F(522+172*.8*min(1,phase)))[0]
   if pattern=="zero":x=522.0
   elif pattern=="resume" and i>=200:x=struct.unpack('<f',F(659.6+min(1,(i-200)/40)*10))[0]
   elif pattern=="float32-small":x=struct.unpack('<f',F(522+(i+1)*0.000001))[0]
   self.render_tip(x)
   output.append({'frame':i+1,'xp_phase':phase,'tip':x,'events':list(self.frame_events),'release_after_render':struct.unpack('<I',self.u.mem_read(S+4,4))[0],'active':struct.unpack('<I',self.u.mem_read(S+0xb8,4))[0],'system_clock':struct.unpack('<f',self.u.mem_read(S+0xc0,4))[0],'last_release':struct.unpack('<f',self.u.mem_read(S+0xc4,4))[0]})
  return {'dt_ms':dt,'pattern':pattern,'frames':output}
def main():
 p=XP();cases=[p.sample(30,130),p.sample(16.667,230),p.sample(30,280,"resume"),p.sample(30,10,"zero"),p.sample(30,60,"float32-small")]
 result={'method':'Full original WinLoseUpdate, particle constructor/Update/Emit and supplied-tip result Render block0xbb316..0xbb3c4. XpBarGrow resource fields/texture vector and bar tips supplied; factory returns prepared system, malloc/rand0/trig/render stubs. No actual texture rendering, loader, GUI/service callback or original global RNG.','source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-xp-chronology-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 for c in cases:print(c['dt_ms'],json.dumps(c['frames'][:3]),'last',c['frames'][-1]['active'])

if __name__=="__main__":main()
