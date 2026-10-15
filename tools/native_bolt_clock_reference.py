"""Original CBolt Update/reset clocks and attachment-point arithmetic.

Update0xddc5c and ResetVisibility0xdd720 execute original interpolation and
float32 fields with supplied frame sequences; CSound::Stop is a recording
stub. SetPosition0xe4228 and SetInitPosition0x7995c execute with explicit
GetCenterOfCell results, null terrain and supplied animator/resource offsets.
No room/tower scheduling, actual sounds, RNG or renderer is executed.
"""
from native_creep_reference import *
import random

class ClockProbe(Probe):
 def hook(self,u,a,size,data):
  if a in [self.stop,END]:u.emu_stop();return
  if a==0x11f75c:self.stops+=1;self.ret();return
  if a==0x10b614:self.point(u.reg_read(UC_ARM_REG_R3),self.center);self.ret();return
  if a==0x1066fc:self.ret(0);return
  super().hook(u,a,size,data)
 def reset(self):
  self.stop=END;self.stops=0;self.u.mem_write(E,bytes(0x10000));self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.reg_write(UC_ARM_REG_LR,END|1)
 def invoke(self,address,args):
  self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(r,v)
  self.u.emu_start(address|1,self.stop,count=10000);assert self.u.reg_read(UC_ARM_REG_PC) in [self.stop,END]
 def state(self):
  return {'enabled':bool(self.u.mem_read(E+0x44,1)[0]),'alive':bool(self.u.mem_read(E+0x54,1)[0]),'opacity':struct.unpack('<f',self.u.mem_read(E+0x48,4))[0],'age':struct.unpack('<f',self.u.mem_read(E+0x4c,4))[0],'fade':struct.unpack('<f',self.u.mem_read(E+0x50,4))[0]}
 def sequence(self,initial,actions):
  self.reset();u=self.u
  for field,offset in [('opacity',0x48),('age',0x4c),('fade',0x50)]:u.mem_write(E+offset,F(initial[field]))
  u.mem_write(E+0x44,bytes([int(initial['enabled'])]));u.mem_write(E+0x54,bytes([int(initial['alive'])]));u.mem_write(E+0x24,I(E+0x6000))
  frames=[]
  for action in actions:
   self.invoke(0xdd720 if action=='reset' else 0xddc5c,[E] if action=='reset' else [E,BITS(action)])
   frames.append({'action':action,'state':self.state(),'stop_calls':self.stops})
  return {'initial':initial,'frames':frames}
 def anchor(self,center,resource_offset,animator_offset):
  self.reset();self.center=center;self.u.mem_write(E+0x1c,I(E+0x1000));self.u.mem_write(E+0x1074,I(E+0x2000))
  self.invoke(0xe4228,[E,7,4]);tower=list(struct.unpack('<2f',self.u.mem_read(E+0x70,8)))
  self.point(E+0x1c8,resource_offset);self.point(E+0x54,animator_offset)
  self.invoke(0x7995c,[E,7,4]);aim=list(struct.unpack('<2f',self.u.mem_read(E+0x190,8)))
  return {'center':center,'resource_offset':resource_offset,'animator_offset':animator_offset,'tower':tower,'aim':aim}

def main():
 p=ClockProbe();cases=[]
 fresh={'enabled':True,'alive':True,'opacity':1,'age':0,'fade':0}
 for actions in [[30]*15,[16.666667]*30,[149,1,30,30,30,30,30,30,30],[150,200],[400],[0,0,150,0,1,199], [100,60,'reset',149,1,200], [150,90,'reset',150,30,300]]:
  cases.append(p.sequence(fresh,actions))
 for enabled,alive in [(False,True),(True,False),(False,False)]:
  cases.append(p.sequence({**fresh,'enabled':enabled,'alive':alive,'age':160,'fade':40,'opacity':0.8},[30,'reset',150,300]))
 rng=random.Random(114)
 for i in range(16):cases.append(p.sequence({**fresh,'age':rng.choice([0,149,150,151]),'fade':rng.choice([0,20,80]),'opacity':rng.choice([0.2,0.7,1])},[rng.choice([0.1,1,10,16.666667,30,60,149,150,200,333.3333]) if j!=10 else 'reset' for j in range(20)]))
 anchors=[p.anchor(center,offset,animator) for center in [[0,0],[140.25,-73.5],[1000000,-1000000]] for offset in [[0,0],[5,-16],[-0.125,8.5]] for animator in [[0,0],[2.5,-3.25]]]
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'anchors':anchors,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-bolt-clock-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'anchors':len(anchors)}))

if __name__=='__main__':main()
