"""Full original DoDamage/Update/Render hit-flash probe.
Supplied records and source-type/clock inputs. Lethal reward credit disabled;
SetDie, gameplay subsystems and GL/frame submission are explicit stubs.
No original whole game, real callers or GPU executes. Full damage reward credit, genuine callers, movement/particle lifetimes and GPU are outside this fixture.
"""
import sys,itertools
sys.path.insert(0,'tools')
from native_creep_status_reference import *
class Hit(Status):
 def hook(self,u,a,size,data):
  if a==0x7a150:
   self.deaths+=1;u.mem_write(E+0x170,b'\x03');self.ret();return
  if a==0xfee78:self.ret(0);return
  if self.updating and a in [0x7a924,0x7beb8,0xfd8a4,0x7bc3c,0x7bbc0,0x7bfa8,0x7bce4,0x7ead0,0x7ee94,0x7f058]:self.ret(0);return
  if a==0x7f5c8 and self.render_add is not None:u.mem_write(E+0x334,bytes([self.render_add]))
  super().hook(u,a,size,data)
 def __init__(self):
  self.updating=False;self.render_add=None;self.deaths=0;super().__init__()
 def state(self):
  b=lambda o:struct.unpack('<I',self.u.mem_read(E+o,4))[0]
  return {'hp_bits':b(0x140),'age_bits':b(0x330),'hit':bool(self.u.mem_read(E+0x334,1)[0]),'running':bool(self.u.mem_read(E+0x335,1)[0]),'last_type':struct.unpack('<i',self.u.mem_read(E+0x34c,4))[0],'state':self.u.mem_read(E+0x170,1)[0],'deaths':self.deaths}
 def init(self,state=0,hp=100,age=0,hit=False,running=False,last_type=0):
  self.reset();self.deaths=0
  for o,v in [(0x140,hp),(0x330,age),(0x2a8,10000)]:self.u.mem_write(E+o,F(v))
  self.u.mem_write(E+0x170,bytes([state]));self.u.mem_write(E+0x334,bytes([hit,running]));self.u.mem_write(E+0x34c,struct.pack('<i',last_type));self.u.mem_write(E+0x2b8,I(E+0x5000))
 def damage(self,amount,kind):
  self.u.mem_write(STACK-0x1000,I(kind));self.invoke(0x7a62c,[E,1,BITS(amount),0]);return self.state()
 def update(self,dt):
  self.updating=True
  try:self.invoke(0x7e8d0,[E,BITS(dt),0])
  finally:self.updating=False
  return self.state()
def main():
 p=Hit();damage=[]
 for state,hp,amount,age,flags,last,kind in itertools.product([0,1,2,3,7],[100],[0,1,100,101],[0,59.9],[(False,False),(True,True)],[0,3],[0,1,2,3,4]):
  inp=dict(state=state,hp=hp,age=age,hit=flags[0],running=flags[1],last_type=last);p.init(**inp);damage.append({'input':{**inp,'amount':amount,'kind':kind},'output':p.damage(amount,kind)})
 updates=[]
 for age,flags,dt in itertools.product([0,30,59,60],[(False,False),(True,True),(False,True),(True,False)],[0,0.001,1,30,60,60.001]):
  inp=dict(age=age,hit=flags[0],running=flags[1]);p.init(**inp);updates.append({'input':{**inp,'dt':dt},'output':p.update(dt)})
 sequence=[];p.init()
 for action in [{'damage':1,'kind':3},{'dt':60},{'damage':1,'kind':3},{'dt':.001},{'damage':1,'kind':3},{'damage':1,'kind':0},{'dt':30},{'damage':1,'kind':1},{'dt':30},{'dt':.001},{'damage':1,'kind':1},{'damage':100,'kind':0}]:
  sequence.append({'input':action,'output':p.damage(action['damage'],action['kind']) if 'damage' in action else p.update(action['dt'])})
 render=[]
 for kind,state,light,alpha,secondary,freeze,slow,add in itertools.product([1,2],[0,2,3],[.3,1],[0,.4,1],[0,.6],[0,1],[-1,.5],[False,True]):
  p.render_add=add;calls=p.render(kind,state,light,freeze,slow,alpha,secondary);render.append({'input':dict(kind=kind,state=state,light=light,alpha=alpha,secondary=secondary,freeze=freeze,slow=slow,add=add),'calls':calls})
 data={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'damage':damage,'updates':updates,'sequence':sequence,'render':render}
 Path('tests/fixtures/native-creep-hit-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'damage':len(damage),'updates':len(updates),'render':len(render),'source_unchanged':data['original_unchanged'],'sequence':sequence}))

if __name__=='__main__':main()
