"""Bounded original portal lifecycle reference with supplied resources.

Full gates/portal constructors, Connect, Portal.Update, Gates.Update and the
original Interpolate execute. Effect/frame metadata, map registration,
player upgrade lookup, animation play/stop, sound and CheckForTransfer are
explicit supplied stubs. No creep transfer, animator clock or GPU executes.
"""
import sys
sys.path.insert(0,'tools')
from native_map_order_reference import *
class PortalProbe(OrderProbe):
 def hook(self,u,a,size,data):
  r0,r1=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1]]
  if a==0x10e064:
   assert self.string(r0)=='Portals';self.ret(self.animator);return
  if a==0x10f0cc:self.plays.append({'animator':r0-E,'state':self.string(r1)});self.ret();return
  if a==0x10f13c:self.stops.append(r0-E);self.ret();return
  if a==0x1034c0:self.registered.append(r1-E);self.ret();return
  if a==0xfee78:self.ret(E+0x8000 if self.upgrade is not None else 0);return
  if a==0xc01d8:assert self.string(r1)=='up_wizard';self.ret(BITS(self.upgrade));return
  if a==0x1206e4:self.sounds.append(self.string(r0));self.ret();return
  if a==0x9c16c:self.transfers+=1;self.ret();return
  super().hook(u,a,size,data)
 def f(self,addr):return struct.unpack('<f',self.u.mem_read(addr,4))[0]
 def i(self,addr):return struct.unpack('<I',self.u.mem_read(addr,4))[0]
 def state(self):
  gates=[]
  for gate in [E+0x1000,E+0x2000]:
   gates.append({'state':self.i(gate+0x58),'active':bool(self.u.mem_read(gate+0x40,1)[0]),'scale':self.f(self.i(gate+0x5c)+0x10),'opening':bool(self.u.mem_read(gate+0x90,1)[0]),'open_remaining':self.f(gate+0x94),'close_remaining':self.f(gate+0x98),'other':self.i(gate+0x7c)-E if self.i(gate+0x7c) else None})
  return {'remaining':self.f(E+0x14),'connected':bool(self.u.mem_read(E+0x18,1)[0]),'deleted':bool(self.u.mem_read(E+0x19,1)[0]),'permanent':bool(self.u.mem_read(E+0x1a,1)[0]),'gates':gates,'plays':list(self.plays),'stops':list(self.stops),'registered':list(self.registered),'sounds':list(self.sounds),'transfer_checks':self.transfers}
 def prepare(self,reload,duration,upgrade=None,permanent=False,active=True,connect=True,sound=True):
  self.reset();self.plays=[];self.stops=[];self.registered=[];self.sounds=[];self.transfers=0;self.upgrade=upgrade
  self.u.mem_write(0x47c4a0,F(reload));self.u.mem_write(0x47c4a4,F(duration))
  self.u.mem_write(E+0x5000+0x48,F(82));self.u.mem_write(E+0x600c,I(E+0x7000));self.u.mem_write(E+0x7074,I(E+0x7100))
  for gate,animator,color in [(E+0x1000,E+0x3000,0),(E+0x2000,E+0x4000,1)]:
   self.animator=animator;self.u.mem_write(animator+0x28,I(E+0x5000));self.invoke(0x9bcc4,[gate,E+0x6000,color])
  self.invoke(0x9c7bc,[E,E+0x6000,1,0]);initial=self.state()
  self.u.mem_write(E+0x1c,I(E+0x2000));self.u.mem_write(E+0x20,I(E+0x1000));self.u.mem_write(E+0x1a,bytes([permanent]))
  for gate in [E+0x1000,E+0x2000]:self.u.mem_write(gate+0x40,bytes([active]))
  if connect:self.invoke(0x9c8ac,[E,int(sound)])
  return initial
 def sequence(self,config,deltas):
  initial=self.prepare(**config);connected=self.state();frames=[]
  for dt in deltas:
   self.plays=[];self.sounds=[];self.transfers=0
   self.invoke(0x9c8f0,[E,BITS(dt),0]);frames.append({'dt':dt,'output':self.state()})
  return {'config':config,'initial':initial,'connected':connected,'frames':frames}
def main():
 p=PortalProbe();cases=[]
 for reload in [800,1000,17.5]:
  for dt in [0,8.333333,33.333333,250]:
   config={'reload':reload,'duration':1500}
   cases.append(p.sequence(config,[dt]*180))
 for config in [dict(reload=1000,duration=15000,permanent=True,sound=False),dict(reload=1000,duration=250),dict(reload=1000,duration=1500,upgrade=1.25),dict(reload=1000,duration=1500,active=False),dict(reload=1000,duration=1500,connect=False)]:
  cases.append(p.sequence(config,[0,1,249,250,0,500,750,1000,1500,100]))
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-portal-lifecycle-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
