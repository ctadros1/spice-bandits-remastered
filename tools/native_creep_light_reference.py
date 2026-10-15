"""Bounded original creep reference with supplied records. GPU/whole game omitted; fixture method states the exact recording stubs and limits."""
import sys
sys.path.insert(0,'tools')
from native_creep_reference import *
class Light(Probe):
 def hook(self,u,a,size,data):
  if a==0x7bfa8:
   self.u.mem_write(E+0x148,struct.pack('<4i',2,3,4,5));self.u.mem_write(E+0x34,F(.4))
   for address,value in [(E+0x9000,self.first),(E+0x9200,self.second)]:
    if value is not None:self.u.mem_write(address+0x1c,F(value))
  if a==0x1066fc and self.movement_mode:
   xy=(u.reg_read(UC_ARM_REG_R1),u.reg_read(UC_ARM_REG_R2));self.cells.append(xy)
   pointer=E+0x9000 if xy==(2,3) and self.first is not None else E+0x9200 if xy==(4,5) and self.second is not None else 0
   self.ret(pointer);return
  super().hook(u,a,size,data)
 def sample(self,a,b,p,speed):
  self.first=a;self.second=b;self.cells=[]
  movement=self.movement(p,0,speed,(0,0),(0,100),(0,200),dt=0)
  return {'current':a,'next':b,'initial_light':.4,'p':p,'speed':speed,'movement':movement,'cell_calls':list(self.cells),'light':struct.unpack('<f',self.u.mem_read(E+0x34,4))[0]}
def main():
 p=Light();cases=[p.sample(a,b,t,speed) for a in [None,.3,.7,1] for b in [None,.3,.7,1] for t in [0,.0001,.25,.5,.75,.9999] for speed in [0,200]]
 result={'method':'Original UpdateMovementAndShooting movement prefix through0x7ca50, GetCell supplied start/next records and existing path/animator/position stubs. dt0 retains explicit movement fractions; map cell light read/interpolation executes. Full combat/room/tick/GPU not executed.','source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 from native_map_order_reference import OrderProbe
 ctor=OrderProbe();ctor.reset();ctor.invoke(1090816,[E,1,2,3]);result['hex_constructor_default_light']=struct.unpack('<f',ctor.u.mem_read(E+0x1c,4))[0];result['hex_constructor_address']='0x10a500'
 Path('tests/fixtures/native-creep-light-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'cell_calls':sum(len(c['cell_calls']) for c in cases),'original_unchanged':result['original_unchanged']}));print(json.dumps(next(c for c in cases if c['current']==.3 and c['next']==1 and c['p']==.5 and c['speed']==200)))

if __name__=="__main__":main()
