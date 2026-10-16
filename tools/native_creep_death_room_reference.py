"""R143 bounded original room/manager/dying-owner chronology.
Full Room.Update/UpdateGame, manager UpdateAllCreeps, Creep.Update,
DoOnDying/UpdateParticles/Particle.Update, Sprite.Update/interpolation and
separate target queries execute. Already-born death roots, linked particles,
room readiness and pause query are supplied. Particle emission, trajectories,
children/resource loading, creation/SetDie and actual destructor are omitted.
Non-tail creep and other room subsystems, UI/audio and virtual destruction
are explicit recording stubs. Target queries occur immediately before and
after each room call, not inside full CheckGameState. No renderer/GPU/game.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_death_tail_reference import *

ROOM=E+0x30000
class RoomDeath(TailClock):
 def __init__(self):
  super().__init__()
  self.stop_addr=struct.unpack('<I',self.u.mem_read(0x40a26c,4))[0]
  self.delta_addr=struct.unpack('<I',self.u.mem_read(0x40a270,4))[0]
  self.sound_addr=struct.unpack('<I',self.u.mem_read(0x40a254,4))[0]
  # Executed protected entry bodies; called leaf functions additionally run
  # from the same unmodified original section mapping.
  addresses={0xd2768,0xd338c,0xfbf10,0x7e8d0,0x7beb8,0x7bce4,0xfc0c8,0x111088,0x1216c4}
  functions={r['address']:r for r in json.loads(Path('original/analysis/functions.json').read_text())}
  assert addresses<=functions.keys()
  self.bodies={a:bytes(self.u.mem_read(a,functions[a]['size'])) for a in sorted(addresses)}
 def hook(self,u,a,size,data):
  methods={0xacb80:'pause-update',0xadc8c:'pause-query',0xd2e50:'first-time-mode',0xd2f98:'game-sync',0xd321c:'game-state-stub',0xfd420:'bubbles',0xfeb44:'indicators',0xd3320:'money',0xca178:'tower-panel',0xbc08c:'winlose',0x9eca4:'footsteps',0x9d9b0:'decals',0xd3558:'paths',0x120b88:'sound-count',0x120b10:'sound-factor',0xd35e8:'important-sounds',0xd1118:'listener',0xd3720:'waves',0xd3bf8:'spawn',0xd4080:'players',0xd4198:'ambient',0xe9d70:'towers',0xe9ae8:'kill-chain',0x9b7f4:'mines',0x9d008:'portals',0xf94c0:'bases'}
  if a in methods:
   self.calls.append(methods[a]);self.ret(self.opened if a==0xadc8c else 0);return
  if a==0x36ca7c:self.ret();return
  if a==END+0x200:
   assert u.reg_read(UC_ARM_REG_R0)==E
   self.calls.append('virtual-destruction-stub');self.removed+=1;self.ret();return
  if a==0x7a8f8:
   self.calls.append('reset-effects-stub');self.ret();return
  if a in [0xd338c,0xfbf10,0x7e8d0,0x7beb8,0x111088]:
   self.calls.append({0xd338c:'update-game',0xfbf10:'manager',0x7e8d0:'creep-update',0x7beb8:'dying',0x111088:'particle-update'}[a])
  super().hook(u,a,size,data)
 def setup_room(self,names,splash):
  self.setup_clocks(names,30);u=self.u;self.removed=0;self.calls=[];self.opened=0
  if not splash:u.mem_write(E+0x288,I(E+0x7000))
  u.mem_write(E+0x160,struct.pack('<2I',0,1))
  vt=E+0x50000;u.mem_write(E,I(vt));u.mem_write(vt+0x24,I((END+0x200)|1))
  vector=E+0x70000;u.mem_write(vector,I(E));u.mem_write(0x47ed54,struct.pack('<3I',vector,vector+4,vector+256));u.mem_write(0x47ed60,b'\1');u.mem_write(0x47ec48,I(37))
  # Explicit empty base vector for the original targeted-owner query.
  u.mem_write(0x40a110,I(E+0x9000));u.mem_write(E+0x9000,bytes(8))
  u.mem_write(ROOM,bytes(0x3000))
  for off,value in [(0x2ac,1),(0x390,ROOM+0x1000),(0x384,ROOM+0x2000),(0x35c,1000),(0x90,5000)]:u.mem_write(ROOM+off,I(value))
  for off in [0x18,0x2b0,0x2f4,0x2f5,0x48d]:u.mem_write(ROOM+off,b'\1')
  u.mem_write(self.delta_addr,F(777));u.mem_write(self.stop_addr,b'\0');u.mem_write(self.sound_addr,F(1))
 def query(self):
  self.invoke(0xfc0c8,[1]);return bool(self.u.reg_read(UC_ARM_REG_R0))
 def snapshot(self):
  u=self.u;start,end=struct.unpack('<2I',u.mem_read(0x47ed54,8));assert end-start in [0,4]
  b=lambda a:struct.unpack('<I',u.mem_read(a,4))[0]
  return {**self.fields(),'retained':end>start,'targeted':self.query(),'removed':self.removed,'room_clock':b(ROOM+0x35c),'survival':b(ROOM+0x90),'delta_bits':b(self.delta_addr),'stop_flag':u.mem_read(self.stop_addr,1)[0]}
 def room_step(self,dt,opened):
  before=self.snapshot();self.calls=[];self.updated=[];self.deleted=[];self.state_calls=[];self.opened=int(opened)
  self.invoke(0xd2768,[ROOM,BITS(dt)])
  calls=list(self.calls);after=self.snapshot()
  assert all(bytes(self.u.mem_read(a,len(body)))==body for a,body in self.bodies.items())
  assert before['targeted']==before['retained'] and after['targeted']==after['retained']
  if opened:
   for key in ['state','systems','sprites','emission_calls','retained','targeted','removed','room_clock','survival','delta_bits']:assert before[key]==after[key],key
   assert 'manager' not in calls and after['stop_flag']==1
  else:
   assert calls.count('manager')==1
   if before['state']==2 and before['retained']:assert not after['retained'] and after['removed']==1 and 'creep-update' not in calls
   elif before['retained']:assert after['retained'] and calls.count('creep-update')==1
  return {'dt_ms':dt,'pause_opened':bool(opened),'before':before,'calls':calls,'after':after}

def main():
 p=RoomDeath();p.definitions=json.loads(Path('game/data/particles.json').read_text())['systems'];bindings=json.loads(Path('game/data/particles.json').read_text())['bindings'];cases=[]
 for resource in ['creeps/creep'+str(i) for i in range(1,11)]:
  names=[b['filename'] for alias,b in sorted(bindings[resource].items()) if 'explosion' in alias]
  for dt in [16.667,30,33.333,100,133.333]:
   for splash in [False,True]:
    p.setup_room(names,splash);rows=[]
    for frame in range(150):
     rows.append(p.room_step(0 if frame==5 else dt,frame in [2,3,4]))
     if rows[-1]['after']['state']==2:
      assert rows[-1]['after']['retained'] and rows[-1]['after']['targeted']
      rows.append(p.room_step(dt,True));rows.append(p.room_step(dt,False));rows.append(p.room_step(dt,False));break
    assert not rows[-1]['after']['retained'] and rows[-1]['after']['removed']==1 and p.emits==0
    cases.append({'resource':resource,'dt_ms':dt,'splash':splash,'frames':rows})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_unchanged':True,'executed_entry_bodies_unchanged':True,'protected_bodies':[{'address':hex(a),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for a,b in p.bodies.items()],'cases':cases}
 Path('tests/fixtures/native-creep-death-room-reference.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'original_unchanged':True,'retained_state2_target_and_pause_then_next_pass_removal':True}))
if __name__=='__main__':main()
