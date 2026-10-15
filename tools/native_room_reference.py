"""Bounded original CRoom::UpdateGame dispatch/timer probe; subsystems stubbed."""
from native_creep_reference import *
class RoomProbe(Probe):
 def hook(self,u,a,size,data):
  calls={0xd3720:'waves',0xd3bf8:'spawn',0xd4080:'players',0xfbf10:'creeps',0xd4198:'ambient',0xe9d70:'towers',0xe9ae8:'kill_chain',0x9b7f4:'mines',0x9d008:'portals',0xf94c0:'bases'}
  if a in calls:
   self.calls.append({'name':calls[a],'registers':[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]});self.ret(0)
  else:super().hook(u,a,size,data)
 def sample(self,dt,replay):
  u=self.u;u.mem_write(E,bytes(2048));self.calls=[];self.stop=END
  u.mem_write(E+0x2ac,I(1));u.mem_write(E+0x35c,I(1000));u.mem_write(E+0x90,I(5000))
  u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1)
  u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,BITS(dt));u.reg_write(UC_ARM_REG_R2,int(replay))
  u.emu_start(0xd338d,END,count=10000)
  return {'dt':dt,'replay':replay,'calls':self.calls,'clock':struct.unpack('<I',u.mem_read(E+0x35c,4))[0],'survival':struct.unpack('<I',u.mem_read(E+0x90,4))[0]}
p=RoomProbe();rows=[p.sample(dt,replay) for replay in [False,True] for dt in [0,1,8,16,16.67,30,33,66,100,133,533]]
result={'method':'Original CRoom::UpdateGame0xd338c, one-player branch, both live/replay flags. All ten subsystem calls stubbed, room clock1000 and survival5000. Captures dispatch count/order/register arguments and timer32-bit arithmetic. Not complete gameplay or iOS execution.','original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':rows}
Path('tests/fixtures/native-room-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(len(rows),'native room cases')
