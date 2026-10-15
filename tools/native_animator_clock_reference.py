"""Full original Animator.Update with supplied animation/clock records.
GL colors and GetTickCount are recording/supplied clock stubs. No loader,
whole room/global delta producer or GPU executes. Original frame arithmetic
and alpha-animation Interpolate execute, with original float32 boundaries.
"""
import sys
sys.path.insert(0,'tools')
from native_animator_render_reference import *
class Clock(Animator):
 def hook(self,u,a,size,data):
  if a==0x10f3a0:return
  if a==0x122070:self.ret(self.now);return
  super().hook(u,a,size,data)
 def sequence(self,count,rate,divisor,multiplier,loop,dts):
  self.reset();self.calls=[];self.rgba=None;self.blend=[];actor=E+0x4c;animation=E+0x10000
  self.u.mem_write(animation,bytes(0x1000))
  for off,val in [(0x28,animation),(0x44,0)]:self.u.mem_write(actor+off,I(val))
  for off,val in [(0x24,multiplier),(0x4c,divisor),(0x64,0)]:self.u.mem_write(actor+off,F(val))
  self.u.mem_write(animation+0xc,I(count));self.u.mem_write(animation+0x10,F(rate));self.u.mem_write(animation+0x14,bytes([loop]))
  stopped=struct.unpack('<I',self.u.mem_read(0x40a26c,4))[0];delta=struct.unpack('<I',self.u.mem_read(0x40a270,4))[0];self.u.mem_write(stopped,b'\0')
  frames=[]
  for dt in dts:
   self.u.mem_write(delta,F(dt));self.calls=[];self.invoke(0x10f3a0,[actor])
   frames.append({'dt':dt,'phase':struct.unpack('<f',self.u.mem_read(actor+0x64,4))[0],'frame':struct.unpack('<i',self.u.mem_read(actor+0x44,4))[0],'finished':bool(self.u.mem_read(actor+0x48,1)[0]),'render_dirty':bool(self.u.mem_read(actor+0x71,1)[0]),'calls':list(self.calls)})
  return frames
if __name__=='__main__':
 p=Clock();cases=[]
 for count in [0,1,2,4]:
  for rate in [.5,4,8,10]:
   for divisor,multiplier in [(1,1),(1,0),(2,1),(.3,1)]:
    for loop in [False,True]:
     source=dict(count=count,rate=rate,divisor=divisor,multiplier=multiplier,loop=loop)
     cases.append({'input':source,'frames':p.sequence(**source,dts=[30]*40+[3000,30])})
 source=dict(count=8,rate=5,divisor=1,multiplier=1,loop=True)
 cases.append({'input':source,'frames':p.sequence(**source,dts=[30,0,0,100])})
 x={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-animator-clock-reference.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'original_unchanged':x['original_unchanged']}))
