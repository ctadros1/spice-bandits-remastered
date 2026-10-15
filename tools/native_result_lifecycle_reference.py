"""Execute original result constructor, closed/open update, and room caller.

Complete GUI/service-heavy Open is omitted; its opening state/win flag are
supplied explicitly after executed closed updates. Drawing/sound/particle
factories and other room subsystems are stubs. The initial closed timer and
room pause/ready/enable/speed gates execute, not whole game or device pixels.
"""
import sys,re
sys.path.insert(0,'tools')
from native_creep_reference import *
class Room(Probe):
 def __init__(self):
  self.calls=[];self.paused=False
  self.stubs={int(a,16):name for a,name in re.findall(r'^([0-9a-f]{8}) (.+)$',Path('docs/mechanics/decompiled/000d2768___ZN5CRoom6UpdateEf.c').read_text(),re.M)}
  for a in [0xbc08c,0x1105e4,0x36ca5c,0x36ca7c]:self.stubs.pop(a,None)
  super().__init__()
 def hook(self,u,a,size,data):
  if a==0xbc08c:self.calls.append({'method':'result-update','dt_bits':u.reg_read(UC_ARM_REG_R1)})
  if a==0xadc8c:self.ret(int(self.paused));return
  if a in self.stubs:self.ret(0);return
  if a in [0x111834,0x120520,0x36ca7c]:self.ret(0);return
  if a==0x36c6cc:
   r0,r1,r2=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]];u.mem_write(r0,bytes([r1&255])*r2);self.ret();return
  super().hook(u,a,size,data)
 def invoke(self,a,args):
  self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,val in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(reg,val)
  try:self.u.emu_start(a|1,END,count=100000)
  except UcError as err:raise RuntimeError(f'{err}; PC={hex(self.u.reg_read(UC_ARM_REG_PC))}') from err
  assert self.u.reg_read(UC_ARM_REG_PC)==END,hex(self.u.reg_read(UC_ARM_REG_PC))
 def run(self,paused,enabled,ready,speed):
  self.calls=[];self.paused=paused;room=E+0x4000
  self.u.mem_write(E,bytes(0x30000))
  for global_address,target,data in [(0x40a20c,E+0x2000,I(1024)),(0x40a204,E+0x2004,I(768)),(0x40a26c,E+0x10020,I(0)),(0x40a124,E+0x10000,bytes(8))]:
   self.u.mem_write(global_address,I(target));self.u.mem_write(target,data)
  self.invoke(0xb959c,[E,room])
  for offset,data in [(0xc,I(E+0x20000)),(0x18,bytes([enabled])),(0x2ac,I(1)),(0x2b0,b'\x01'),(0x2f5,b'\x01'),(0x324,b'\x00'),(0x48d,bytes([ready])),(0x384,I(E)),(0x390,I(E+0x6000)),(0x3f8,I(speed))]:self.u.mem_write(room+offset,data)
  self.invoke(0xd2768,[room,BITS(30)])
  return {'paused':paused,'enabled':enabled,'ready':ready,'speed_enum':speed,'calls':list(self.calls),'closed_delay':struct.unpack('<f',self.u.mem_read(E+0xa0,4))[0]}

 def lifecycle(self,closed_steps,dt=30):
  self.u.mem_write(E,bytes(0x30000))
  self.u.mem_write(0x40a20c,I(E+0x2000));self.u.mem_write(E+0x2000,I(1024))
  self.u.mem_write(0x40a204,I(E+0x2004));self.u.mem_write(E+0x2004,I(768))
  self.invoke(0xb959c,[E,E+0x4000]);constructor=self.fields()
  for i in range(closed_steps):self.invoke(0xbc08c,[E,BITS(dt)])
  closed=self.fields()
  self.u.mem_write(E,I(0));self.u.mem_write(E+0x9c,b'\x01')
  frames=[]
  for i in range(260):
   self.invoke(0xbc08c,[E,BITS(dt)])
   frames.append({'dt_ms':dt,'fields':self.fields()})
  return {'closed_steps':closed_steps,'dt_ms':dt,'constructor':constructor,'closed':closed,'opening_state_supplied':0,'win_flag_supplied':True,'frames':frames}
 def fields(self):
  result={key:struct.unpack('<f',self.u.mem_read(E+off,4))[0] for key,off in [('alpha',0x14),('open_phase',0x18),('delay',0xa0),('xp_phase',0xa4),('medal_clock',0xac),('spice_phase',0xb4)]}
  result['state']=struct.unpack('<I',self.u.mem_read(E,4))[0];return result

def main():
 p=Room()
 room=[p.run(paused,enabled,ready,speed) for paused in [False,True] for enabled in [False,True] for ready in [False,True] for speed in [0,1,2]]
 lifecycle=[p.lifecycle(n) for n in [0,10,50,100,1000]]+[p.lifecycle(180,16.667)]
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'room_cases':room,'lifecycle_cases':lifecycle,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-result-lifecycle-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'room_cases':len(room),'room_calls':sum(len(c['calls']) for c in room),'lifecycle_cases':len(lifecycle),'open_frames':sum(len(c['frames']) for c in lifecycle),'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
