"""Original creep construction depth and complete supplied-position updates.

Constructor suffix0x7878c..0x78804 (resource absent stops0x7887c) reads the
initial RunDownRight animation height and integer depth_pos override. Full
UpdatePosition0x7d108 runs against supplied normal/corner records; narrow
animator direction/name callbacks are inherited recording stubs. Attack
position-copy suffix0x7cc52..0x7cca2 runs with explicit logical coordinates.
No constructor lifetime, global jitter RNG, GPU, services or whole game.
"""
from native_map_order_reference import *


class CreepDepthProbe(OrderProbe):
 def declaration(self,height,override=None,resource=True,animation=True):
  self.reset(0x78804 if resource else 0x7887c);self.override=override
  sp=self.u.reg_read(UC_ARM_REG_SP)
  for offset in [0x140,0xe4,0xc8,0xb0]:self.u.mem_write(sp+offset,I(E))
  self.u.mem_write(E+0x250,I(E+0x2000 if resource else 0));self.u.mem_write(E+0x204c,I(E+0x3000))
  self.u.mem_write(E+0x74,I(E+0x4000 if animation else 0));self.u.mem_write(E+0x4048,F(height))
  self.u.reg_write(UC_ARM_REG_R0,E+0x2000 if resource else 0)
  self.invoke(0x7878c,[])
  return struct.unpack('<f',self.u.mem_read(E+0x14,4))[0]
 def pose(self):
  pair=lambda offset:list(struct.unpack('<2f',self.u.mem_read(E+offset,8)))
  return {'animator':pair(0x4c),'blending_animator':pair(0xc0),'aim':pair(0x190),'depth_top':struct.unpack('<i',self.u.mem_read(E+0xc,4))[0]}
 def position(self,height,logical,jitter,offset,corner,p):
  self.reset();self.current='RunDown';self.names={}
  self.u.mem_write(E+0x14,F(height));self.u.mem_write(E+0x2a2,bytes([corner]));self.u.mem_write(E+0x158,F(p))
  self.point(E+0x188,logical);self.point(E+0x1a0,logical);self.point(E+0x180,logical)
  self.point(E+0x1c8,jitter);self.point(E+0x54,offset)
  self.point(E+0x308,(0,75));self.point(E+0x310,(25,125))
  self.invoke(0x7d108,[E,1])
  return self.pose()
 def attack_position(self,height,logical,offset):
  self.reset(0x7cca2);self.point(E+0x188,logical);self.point(E+0x54,offset);self.u.mem_write(E+0x14,F(height))
  self.u.reg_write(UC_ARM_REG_R6,E);self.u.reg_write(UC_ARM_REG_R10,E+0x188)
  self.invoke(0x7cc52,[])
  return self.pose()


def main():
 p=CreepDepthProbe();declarations=[];positions=[];attacks=[]
 for height in [0,38,100,128,86,64,87.25]:
  for override,resource,animation in [(None,False,True),(None,True,True),(17,True,True),(-3,True,True),(None,True,False)]:
   declarations.append({'height':height,'override':override,'resource':resource,'animation':animation,'output':p.declaration(height,override,resource,animation)})
 for y in [-100.75,-7,-.125,0,7,49.5,150,150.875,16777218]:
  for height in [0,38,64,86,100,128,87.25]:
   for jitter in [(0,0),(2,-3),(-.125,.375)]:
    for corner in [False,True]:
     for progress in [.05,.8,.95]:
      logical=[125.25,y];offset=[-4,7]
      positions.append({'height':height,'logical':logical,'jitter':jitter,'offset':offset,'corner':corner,'progress':progress,'output':p.position(height,logical,jitter,offset,corner,progress)})
   for offset in [(0,0),(-4,7)]:
    logical=[125.25,y];attacks.append({'height':height,'logical':logical,'offset':offset,'output':p.attack_position(height,logical,offset)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'declarations':declarations,'positions':positions,'attacks':attacks,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-creep-depth-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'declarations':len(declarations),'positions':len(positions),'attacks':len(attacks),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
