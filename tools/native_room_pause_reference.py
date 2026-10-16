import sys
sys.path.insert(0,'tools')
from native_creep_reference import *
class RoomPause(Probe):
 def __init__(self):
  super().__init__();self.stop_addr=struct.unpack('<I',self.u.mem_read(0x40a26c,4))[0];self.delta_addr=struct.unpack('<I',self.u.mem_read(0x40a270,4))[0];self.sound_addr=struct.unpack('<I',self.u.mem_read(0x40a254,4))[0]
 def hook(self,u,a,size,data):
  methods={0xacb80:'pause-update',0xadc8c:'pause-is-opened',0xd2e50:'first-time-mode',0xd2f98:'game-sync',0xd321c:'game-state',0xfd420:'bubbles',0xfeb44:'indicators',0xd3320:'money',0xca178:'tower-panel',0xbc08c:'winlose',0x9eca4:'footsteps',0x9d9b0:'decals',0xd3558:'paths',0x120b88:'sound-count',0x120b10:'sound-factor',0xd35e8:'important-sounds',0xd1118:'listener',0xd3720:'waves',0xd3bf8:'spawn',0xd4080:'players',0xfbf10:'creeps',0xd4198:'ambient',0xe9d70:'towers',0xe9ae8:'kill-chain',0x9b7f4:'mines',0x9d008:'portals',0xf94c0:'bases'}
  if a==0x36ca7c:self.ret();return
  if a==0xd338c:self.calls.append({'name':'update-game','arg1_bits':u.reg_read(UC_ARM_REG_R1),'arg2':u.reg_read(UC_ARM_REG_R2)})
  elif a in methods:
   self.calls.append({'name':methods[a],'arg1_bits':u.reg_read(UC_ARM_REG_R1)})
   self.ret(self.opened if a==0xadc8c else 0);return
  super().hook(u,a,size,data)
 def sample(self,dt,speed,pause_present,opened,initial_stop,extra):
  u=self.u;u.mem_write(E,bytes(0x3000));self.stop=END;self.calls=[];self.opened=opened
  for off,v in [(0x2ac,1),(0x390,E+0x1000 if pause_present else 0),(0x2f0,extra),(0x3f8,speed),(0x384,E+0x2000),(0x35c,1000),(0x90,5000)]:u.mem_write(E+off,I(v))
  for off in [0x18,0x2b0,0x2f4,0x2f5,0x48d]:u.mem_write(E+off,b'\1')
  u.mem_write(E+0x438,F(888));u.mem_write(self.delta_addr,F(777));u.mem_write(self.stop_addr,bytes([initial_stop]));u.mem_write(self.sound_addr,F(1))
  code=bytes(u.mem_read(0xd2768,0x6e8));game_code=bytes(u.mem_read(0xd338c,0x1cc));u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,BITS(dt))
  try:u.emu_start(0xd2769,END,count=100000)
  except UcError as e:raise RuntimeError(str(e)+' PC='+hex(u.reg_read(UC_ARM_REG_PC)))
  assert u.reg_read(UC_ARM_REG_PC)==END and bytes(u.mem_read(0xd2768,0x6e8))==code and bytes(u.mem_read(0xd338c,0x1cc))==game_code
  bits=lambda a:struct.unpack('<I',u.mem_read(a,4))[0]
  return {'calls':self.calls,'stop_flag':u.mem_read(self.stop_addr,1)[0],'room_delta_bits':bits(E+0x438),'global_delta_bits':bits(self.delta_addr),'multiplier_bits':bits(E+0x3fc),'clock':bits(E+0x35c),'survival':bits(E+0x90)}
def main():
 p=RoomPause();cases=[]
 for dt in [0,.016667,16.67,30,100]:
  for speed in [0,1,2]:
   for pause_present,opened in [(False,0),(True,0),(True,1)]:
    for initial_stop in [0,1]:
     for extra in [0,1]:
      inp=dict(dt=dt,speed=speed,pause_present=pause_present,opened=opened,initial_stop=initial_stop,extra=extra)
      cases.append({'input':inp,'output':p.sample(**inp)})
 for c in cases:
  inp=c['input'];out=c['output'];calls=out['calls'];game=[x for x in calls if x['name']=='update-game'];creeps=[x for x in calls if x['name']=='creeps']
  if inp['opened']:
   assert not game and not creeps and out['stop_flag']==1 and out['room_delta_bits']==BITS(888) and out['global_delta_bits']==BITS(777) and out['clock']==1000 and out['survival']==5000
  else:
   expected=BITS(struct.unpack('<f',F(inp['dt']))[0]*(1<<inp['speed']))
   assert len(game)==len(creeps)==1 and game[0]['arg1_bits']==expected and out['room_delta_bits']==expected and out['global_delta_bits']==expected
   assert out['multiplier_bits']==BITS(1<<inp['speed']) and out['stop_flag']==(inp['initial_stop'] if inp['extra'] else 0)
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 record={'original_sha256':EXPECTED_SHA,'original_file_unchanged':True,'original_update_and_updategame_bodies_unchanged':True,'global_addresses':{'stop_all_animation':p.stop_addr,'delta_time':p.delta_addr,'sound_factor':p.sound_addr},'cases':cases,'scope':'Full original CRoom.Update0xd2768 and actualUpdateGame0xd338c single-player selectors with supplied ready/replay/update flags. PauseScreen.Update/IsOpened and other explicit subsystem/UI/audio calls are recording stubs; creepmanager call recorded, not executed. Globals use original resolved storage initialized with suppliedsentinels. Opened singleplayer skipsUpdateGame/creeps and preserves room/globaldelta; speed0/1/2 gives1x/2x/4x. room+2f0 meaningnotidentified; tested asprovidedfield. No UIKit/whole-room render/actual pause animation/GPU/game port.'}
 Path('tests/fixtures/native-room-pause-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'paused_creep_calls':sum(sum(x['name']=='creeps' for x in c['output']['calls']) for c in cases if c['input']['opened']==1),'active_creep_calls':sum(sum(x['name']=='creeps' for x in c['output']['calls']) for c in cases if c['input']['opened']==0),'original_unchanged':True}))
if __name__=='__main__':main()
