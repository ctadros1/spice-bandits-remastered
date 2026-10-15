"""Full original Animator.Render with supplied two-frame metadata.
Animator.Update and final RenderFrame/GPU are recording stubs. No loader,
whole actor/room clock or complete game executes.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_status_reference import *
class Animator(Status):
 def hook(self,u,a,size,data):
  if a==0x10f1c4:
   self.calls.append({'method':'frame','frame':u.reg_read(UC_ARM_REG_R1)-E,'rgba':self.rgba,'blend':list(self.blend)})
   self.ret();return
  super().hook(u,a,size,data)
 def sample(self,phase,alpha,geometry,interpolation):
  self.reset();self.calls=[];self.rgba=[.3,.3,.3,1];self.blend=[1,771]
  actor=E+0x4c;animation=E+0x10000;frames=E+0x10100
  self.u.mem_write(animation,bytes(0x1000))
  self.u.mem_write(actor+0x28,I(animation));self.u.mem_write(actor+0x2c,b'\x01');self.u.mem_write(actor+0x34,F(alpha));self.u.mem_write(actor+0x38,F(.3*alpha));self.u.mem_write(actor+0x44,I(int(phase)%2));self.u.mem_write(actor+0x64,F(phase))
  self.u.mem_write(animation+0xc,I(2));self.u.mem_write(animation+0x28,bytes([interpolation]));self.u.mem_write(animation+0x34,I(frames));self.u.mem_write(animation+0x38,I(frames+8))
  for i in range(2):
   frame=E+0x11000+i*0x100;self.u.mem_write(frames+i*4,I(frame));self.u.mem_write(frame+0x18,F(3 if i==1 and geometry=='offset' else 0));self.u.mem_write(frame+0x1c,F(0));self.u.mem_write(frame+0x2c,I(64+(i if geometry=='atlas_x' else 0)));self.u.mem_write(frame+0x30,I(64))
  self.invoke(0x10f54c,[actor]);return self.calls
if __name__=='__main__':
 p=Animator();cases=[]
 for interpolation in [False,True]:
  for geometry in ['same','offset','atlas_x']:
   for alpha in [0,.35,1]:
    for phase in [0,.1,.25,.5,.75,.999,1,1.25,1.75,1.999]:cases.append({'phase':phase,'alpha':alpha,'geometry':geometry,'interpolation':interpolation,'calls':p.sample(phase,alpha,geometry,interpolation)})
 x={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-animator-render-reference.json').write_text(json.dumps(x,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'frames':sum(sum(q['method']=='frame' for q in c['calls']) for c in cases),'original_unchanged':x['original_unchanged']}))
 for c in cases:
  if c['interpolation'] and c['geometry']=='offset' and c['alpha']==1:print(json.dumps(c))
