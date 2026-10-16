"""R144 bounded original room victory admission across retained death owners.
Executes original Room.Update/CheckGameState/UpdateGame/creep manager,
Creep.Update/death/particle/sprite tails and target queries from R143.
A supplied nonempty base vector and recording IsPlayerBasesAlive=1,
IsAnyCreepsInWave=0, GameEnd and WinLose.Open stubs isolate admission.
GameEnd is a recording stub: actual outcome mutation/UI/rewards/services
are NOT executed. No whole SetDie/resource/child trajectory/destructor/GPU.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_death_room_reference import *
class Victory(RoomDeath):
 def __init__(self):
  super().__init__();functions={r['address']:r for r in json.loads(Path('original/analysis/functions.json').read_text())};self.bodies[0xd321c]=bytes(self.u.mem_read(0xd321c,functions[0xd321c]['size']))
 def hook(self,u,a,size,data):
  if a==0xd321c:self.calls.append('game-state');Probe.hook(self,u,a,size,data);return
  if a==0xfc0c8:self.calls.append('target-query')
  if a in [0xf9504,0xd8ff0,0xd9034,0xbca74]:
   if a==0xd9034:self.calls.append('game-end-stub:'+str(u.reg_read(UC_ARM_REG_R1)))
   elif a==0xbca74:self.calls.append('winlose-open-stub:'+str(u.reg_read(UC_ARM_REG_R1)))
   else:self.calls.append('bases-alive-stub' if a==0xf9504 else 'wave-empty-stub')
   self.ret(1 if a==0xf9504 else 0);return
  super().hook(u,a,size,data)
 def setup_room(self,names,splash):
  super().setup_room(names,splash);u=self.u
  vector=E+0x9200;u.mem_write(E+0x9000,struct.pack('<2I',vector,vector+4));u.mem_write(vector,I(E+0x9400));u.mem_write(E+0x9454,I(1));u.mem_write(ROOM+0x2e0,I(1))
def main():
 p=Victory();particles=json.loads(Path('game/data/particles.json').read_text());p.definitions=particles['systems'];cases=[]
 for resource in ['creeps/creep'+str(i) for i in range(1,11)]:
  names=[b['filename'] for alias,b in sorted(particles['bindings'][resource].items()) if 'explosion' in alias]
  for splash in [False,True]:
   p.setup_room(names,splash);rows=[]
   for frame in range(150):
    rows.append(p.room_step(30,frame in [2,3,4]))
    if rows[-1]['after']['state']==2:
     rows.append(p.room_step(30,True));rows.append(p.room_step(30,False));rows.append(p.room_step(30,False));break
   assert not rows[-1]['after']['retained']
   admissions=[i for i,row in enumerate(rows) if 'game-end-stub:2' in row['calls']]
   removals=[i for i,row in enumerate(rows) if 'virtual-destruction-stub' in row['calls']]
   assert len(admissions)==len(removals)==1 and admissions[0]==removals[0]+1
   assert rows[admissions[0]]['calls'].index('game-state')<rows[admissions[0]]['calls'].index('manager')
   assert 'winlose-open-stub:1' in rows[admissions[0]]['calls']
   for row in rows:
    if row['before']['retained']:assert 'game-end-stub:2' not in row['calls']
    if row['pause_opened']:assert 'game-state' not in row['calls']
   cases.append({'resource':resource,'splash':splash,'removal_frame':removals[0],'first_victory_submission_frame':admissions[0],'frames':rows})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_unchanged':True,'executed_entry_bodies_unchanged':True,'protected_bodies':[{'address':hex(a),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for a,b in sorted(p.bodies.items())],'cases':cases}
 Path('tests/fixtures/native-creep-death-victory-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'first_victory_submission_one_active_room_call_after_removal':True,'original_unchanged':True}))
if __name__=='__main__':main()
