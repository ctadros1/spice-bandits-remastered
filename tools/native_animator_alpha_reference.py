"""Full original alpha-animation Update with supplied monotonic clock.
GetTickCount and GL are supplied/recording stubs; Interpolate executes. No
original wallclock producer, loader, room, GPU or whole game executes.
"""
import sys
sys.path.insert(0,'tools')
from native_animator_render_reference import *
class Alpha(Animator):
 def hook(self,u,a,size,data):
  if a==0x10f3a0:return
  if a==0x122070:self.ret(self.now);return
  super().hook(u,a,size,data)
 def sequence(self,rate,start,end,loop,interval):
  self.reset();actor=E+0x4c;animation=E+0x10000;self.u.mem_write(animation,bytes(0x1000));self.u.mem_write(actor+0x28,I(animation));self.u.mem_write(animation+0x29,b'\x01');self.u.mem_write(animation+0x14,bytes([loop]));self.u.mem_write(animation+0x10,F(rate))
  self.u.mem_write(actor+0x58,F(start));self.u.mem_write(actor+0x5c,F(end))
  stopped=struct.unpack('<I',self.u.mem_read(0x40a26c,4))[0];self.u.mem_write(stopped,b'\0')
  frames=[]
  for i in range(160):
   self.now=100+i*interval;self.calls=[];self.rgba=None;self.blend=[];self.invoke(0x10f3a0,[actor])
   frames.append({'now':self.now,'timer_start':struct.unpack('<I',self.u.mem_read(actor+0x3c,4))[0],'from':struct.unpack('<f',self.u.mem_read(actor+0x58,4))[0],'to':struct.unpack('<f',self.u.mem_read(actor+0x5c,4))[0],'finished':bool(self.u.mem_read(actor+0x48,1)[0]),'rgba':self.rgba,'calls':list(self.calls)})
  return frames
if __name__=='__main__':
 p=Alpha();cases=[]
 for rate in [.5,12]:
  for start,end in [(0,1),(1,0)]:
   for loop in [False,True]:
    for interval in [16,30,100]:
     source=dict(rate=rate,start=start,end=end,loop=loop,interval=interval)
     cases.append({'input':source,'frames':p.sequence(**source)})
 x={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA};Path('tests/fixtures/native-animator-alpha-reference.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'original_unchanged':x['original_unchanged']}))
