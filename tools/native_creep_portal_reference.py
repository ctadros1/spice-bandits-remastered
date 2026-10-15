"""Full original ProcessPortal and interpolation on supplied mature-creep fields.

Original method, interpolation and math execute. No constructor, movement,
gate transfer/queue, animator Update/Render, particles, room or GPU executes.
"""
import sys
sys.path.insert(0,'tools')
from native_map_order_reference import *
class CreepPortal(OrderProbe):
 def state(self):
  f=lambda o:struct.unpack('<f',self.u.mem_read(E+o,4))[0]
  return {'clock':f(0x350),'state':struct.unpack('<I',self.u.mem_read(E+0x354,4))[0],'visible':bool(self.u.mem_read(E+0x2dc,1)[0]),'scale':[f(0x5c),f(0x60)],'secondary_scale':[f(0xd0),f(0xd4)],'health_alpha':f(0x2e0),'particle_scale':f(0x5000),'anim_alpha':f(0x80),'anim_color':f(0x84)}
 def sequence(self,state,base,light,clock,deltas):
  self.reset();self.u.mem_write(E+0x354,I(state));self.u.mem_write(E+0x350,F(clock));self.u.mem_write(E+0x2dc,b'\x01');self.u.mem_write(E+0x34,F(light));self.u.mem_write(E+0x2e0,F(1))
  self.point(E+0x1c0,base);self.point(E+0x5c,base);self.point(E+0xd0,base);self.u.mem_write(E+0x2fc,I(E+0x5000));self.u.mem_write(E+0x5000,F(1)+F(.8));self.u.mem_write(E+0x80,F(1)+F(light))
  initial=self.state();frames=[]
  for dt in deltas:self.invoke(0x7ee94,[E,BITS(dt)]);frames.append({'dt':dt,'output':self.state()})
  return {'input':{'state':state,'base':base,'light':light,'clock':clock,'particle_base':.8},'initial':initial,'frames':frames}
def main():
 p=CreepPortal();cases=[]
 duration=struct.unpack('<f',p.u.mem_read(0x7f054,4))[0]
 for state in [0,1,2,3]:
  for base in [[1,1],[.75,1.2]]:
   for light in [.3,1]:
    for dt in [8.333333,30,133]:cases.append(p.sequence(state,base,light,0,[0]+[dt]*40))
 for state in [1,2]:
  for clock in [duration*.5-1,duration*.5,duration-1,duration,duration+1]:cases.append(p.sequence(state,[1,1],1,clock,[0,1,1,133]))
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'duration_ms':duration,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-creep-portal-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'duration_ms':duration,'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
