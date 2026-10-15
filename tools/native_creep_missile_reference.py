"""Original complete creep-missile constructor and nonimpact Update.

Supplied owner/resource/base/origin records. Texture/particle lookup return
null and collision is explicitly forced false. Original normalize, distance,
float32 steering and body-routing flag execute; inherited angle/name/framework
stubs record no original rendering, explosion or whole owner lifetime.
"""
import sys
sys.path.insert(0,'tools')
from native_map_order_reference import *
class Missile(OrderProbe):
 def hook(self,u,a,size,data):
  if a==0x11794c:self.ret(E+0x6000 if self.string(u.reg_read(UC_ARM_REG_R1))=='shoot_bomb' and self.bomb else 0);return
  if a in [0x1177e0,0x111834,0x1108b8]:self.ret(0);return
  super().hook(u,a,size,data)
 def create(self,point,target,bomb=False):
  self.reset();self.calls=[];self.bomb=bomb
  owner=E+0x1000;res=E+0x3000;base=E+0x2000
  self.u.mem_write(owner+0x250,I(res));self.u.mem_write(res+0x20,I(3000));self.u.mem_write(res+0x4c,I(E+0x4000))
  self.point(base+0x64,target);self.point(E+0x5000,point)
  sp=STACK-0x1000;self.u.mem_write(sp,I(base)+F(12.5))
  self.invoke(0x80bc0,[E,owner,25,E+0x5000])
  return self.state()
 def state(self):
  point=lambda off:list(struct.unpack('<2f',self.u.mem_read(E+off,8)))
  return {'start':point(0x2c),'pos':point(0x34),'previous':point(0x3c),'velocity':point(0x4c),'acceleration':point(0x78),'integral':point(0x80),'body_flag':bool(self.u.mem_read(E+0xa0,1)[0]),'active':self.u.mem_read(E,1)[0],'impact':self.u.mem_read(E+0x68,1)[0]}
 def update(self,dt):
  self.invoke(0x8120c,[E,BITS(dt),0]);return self.state()
def main():
 p=Missile();out=[];boundaries=[]
 for point,target in [([0,0],[1000,0]),([120.25,-70.5],[513.75,329.25]),([100,100],[-500,300]),([1000,1000],[1100,1000])]:
  for bomb in [False,True]:
   for dt in [0,16.666667,30,100,150]:
    initial=p.create(point,target,bomb);frames=[]
    for i in range(25):frames.append(p.update(dt))
    out.append({'point':point,'target':target,'bomb':bomb,'dt':dt,'initial':initial,'frames':frames})
 for delta in [[0,0],[29.999998,0],[30,0],[30.000002,0],[31,0],[0,30],[0,30.000002],[18,24],[18,24.000002]]:
  initial=p.create([0,0],[1000,0]);position=[initial['start'][i]+delta[i] for i in range(2)]
  for off in [0x34,0x44]:p.point(E+off,position)
  p.point(E+0x2064,position)
  before=p.state();after=p.update(30)
  boundaries.append({'delta':delta,'before':before,'destination':position,'after':after})
 result={'cases':out,'boundaries':boundaries,'method':__doc__+' Original normalize/distance/float32 motion execute. Bomb direction stub supplies down. Boundary cases supply a stationary missile/target and retain the actual post-update distance comparison.','source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-creep-missile-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(out),'frames':sum(len(c['frames']) for c in out),'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
