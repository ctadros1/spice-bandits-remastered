"""R156 joined original Disco caller/duration/player timer and actor expiry.
Full ActiveLsd420/GetLsdDuration164/ProcessPlayers280 plus R155 five full
actor/manager bodies execute. Room+0x334 is supplied1 to bypass online ObjC
payload creation; one/two player vectors, upgrade levels/percent and base
integer duration are supplied. Play/stop sound, upgrade lookup/percentage,
GetCell, displacement release, hover and path recomputation are stubs.
No original constructor, room UpdateGame/ProcessWaves, movement/pathfinder,
particle emission, profile/network/audio backend, renderer/GPU or game runs.
"""
import itertools,argparse
from native_creep_lsd_reference import *
PANEL=E+0x14000;ROOM=E+0x15000;PLAYERVECTOR=E+0x16000;PLAYERITEMS=E+0x17000;BASE=E+0x17100
class Timer(Lsd):
 def __init__(self):
  super().__init__();self.levels={};self.percent={}
  for a,n in [(0x98b6c,420),(0xc02b8,164),(0xd4080,280)]:self.body[a]=bytes(self.u.mem_read(a,n))
 def hook(self,u,a,size,data):
  if a in [0x7fa18,0xd96d8]:
   key=self.string(u.reg_read(UC_ARM_REG_R1));source=self.levels if a==0x7fa18 else self.percent;v=source.get(key,0);self.calls.append({'call':'UpgradeLevel-stub' if a==0x7fa18 else 'UpgradePercent-stub','key':key,'value':v});self.ret(v);return
  if a in [0xd8b00,0xc9620,0xff0d4,0x1206e4]:
   self.calls.append({'call':{0xd8b00:'PlayLsdSound-stub',0xc9620:'StopLsdSound-stub',0xff0d4:'PlayerStatistics-stub',0x1206e4:'PlaySoundOnce-stub'}[a]});self.ret();return
  if a==0xfc0a0:self.calls.append({'call':'SetCanUseLsd-full'})
  super().hook(u,a,size,data)
 def setup(self,row,base,levels,counts):
  self.prepare([row]);self.levels=levels;self.percent={'up_pharm':5,'up_wizard':5};self.u.mem_write(BASE,I(base));self.u.mem_write(0x40a240,I(BASE));self.u.mem_write(PANEL+4,I(ROOM));self.u.mem_write(ROOM+0x334,I(1));self.u.mem_write(ROOM+0x2ac,I(len(counts)));self.u.mem_write(ROOM+0x2a8,I(PLAYER));self.u.mem_write(0x40a124,I(PLAYERVECTOR));self.u.mem_write(PLAYERVECTOR,struct.pack('<2I',PLAYERITEMS,PLAYERITEMS+4*len(counts)))
  for i,c in enumerate(counts):self.u.mem_write(PLAYERITEMS+i*4,I(PLAYER+i*0x100));self.u.mem_write(PLAYER+i*0x100+4,I(i+1));self.u.mem_write(PLAYER+i*0x100+0x38,struct.pack('<i',c))
 def counts(self,n):return [struct.unpack('<i',self.u.mem_read(PLAYER+i*0x100+0x38,4))[0] for i in range(n)]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-lsd-timer-reference.json');args=parser.parse_args()
 p=Timer();cases=[]
 for state,base,pharm,wizard,initial in itertools.product([0,1,4,7],[0,1,17,10000,16777217],[0,3,10],[0,2,10],[-1,0,1]):
  row={'state':state,'previous':4,'cell':0,'flag214':False,'slot':True,'existing':False};p.setup(row,base,{'up_pharm':pharm,'up_wizard':wizard},[initial]);p.invoke(0x98b6c,[PANEL,PLAYER]);result=p.u.reg_read(UC_ARM_REG_R0);start={'returned':result,'counts':p.counts(1),'actor':p.snapshot(),'calls':p.calls.copy()};frames=[]
  for dt in [0,.1,16.667,30,10001,20000,30,0]:
   p.invoke(0xd4080,[ROOM,BITS(dt)]);playerscalls=p.calls.copy();counts=p.counts(1);p.invoke(0x7bbc0,[E]);frames.append({'supplied_delta':dt,'counts':counts,'actor':p.snapshot(),'player_calls':playerscalls,'actor_calls':p.calls.copy()})
  cases.append({'input':{'actor':row,'base_duration':base,'levels':{'up_pharm':pharm,'up_wizard':wizard},'initial_counter':initial,'room334':1,'player_count':1},'activation':start,'frames':frames})
 timers=[]
 for counts in [[],[0],[-1],[1],[17],[30],[10000],[1,0],[0,1],[1,10000],[10000,1],[0,0]]:
  for dt in [0,.1,16.667,30,10001]:
   row={'state':7,'previous':4,'cell':0,'flag214':True,'slot':True,'existing':False};p.setup(row,10000,{},counts);before=p.snapshot();p.invoke(0xd4080,[ROOM,BITS(dt)]);timers.append({'input':{'counts':counts,'delta':dt},'before':before,'after':p.snapshot(),'counts':p.counts(len(counts)),'calls':p.calls.copy()})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_body_bytes':{hex(a):len(b) for a,b in p.body.items()},'original_unchanged':True,'cases':cases,'timer_cases':timers};assert len(cases)==540 and len(timers)==60
 path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'timer_cases':len(timers),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
