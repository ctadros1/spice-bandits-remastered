"""R181 reference: original C2/source/normal movement then full DoDamage/SetDie.
Supplied graph/resource/source/base/room/player records. Full source-path and
normal movement chain from R179. Resource/registry/string/random/math/audio
callbacks remain explicit. Portal/tower cleanup, particle Emit, Objective-C
notification/indicator and supplied Interest level/percent are recorded stubs.
Texture lookup returns null as before: no death sprites/decal/GPU identity.
This does not execute full room/player/resource producers or the whole game.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_spawn_path_reference import *
class RewardConstructor(SpawnPathConstructor):
 def __init__(self):
  self.reward_trace=deque(maxlen=160);super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0x7a62c,0x7a150]:
   self.actual.add(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
  self.damaging=False;self.upgrade=0;self.player=E+0x18a000
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  self.reward_trace.append({"pc":hex(a),"r0":hex(r0),"r1":hex(r1),"lr":hex(u.reg_read(UC_ARM_REG_LR))})
  if a in [0x7a62c,0x7a150]:self.events.append({'kind':'damage-death-full','address':hex(a)})
  if a==0x36c12c:self.ret(self.next_nodes[r0]);return
  if a==0x36c4dc and self.damaging:
   value=struct.unpack('<f',I(r0))[0];result=BITS(math.floor(value));self.events.append({'kind':'reward-floor-stub','input_bits':r0,'output_bits':result});self.ret(result);return
  if a==0xfee78:self.events.append({'kind':'player-lookup-stub','owner':r0});self.ret(self.player);return
  if a in [0x9cec8,0xe9a74]:self.events.append({'kind':'owner-clean-stub','address':hex(a)});self.ret();return
  if a==0x7fa18:self.events.append({'kind':'upgrade-level-stub','name':self.string(r1)});self.ret(self.upgrade);return
  if a==0xd96d8:self.events.append({'kind':'upgrade-percent-stub','name':self.string(r1)});self.ret(5);return
  if a==0x36be6c:self.events.append({'kind':'objc-notification-stub','selector':self.string(r1),'argument_bits':r2});self.ret(0);return
  if a==0x36c8ac:
   fmt=self.string(r1);assert fmt in ['%d','%i','+%d'],fmt;value=r2 if r2<2**31 else r2-2**32;s=(fmt%value).encode();u.mem_write(r0,s+b'\0');self.ret(len(s));return
  if a==0xfe998:self.events.append({'kind':'indicator-stub','text':self.string(r1),'position_bits':list(struct.unpack('<2I',u.mem_read(r0,8)))});self.ret();return
  if a==0x111418:self.events.append({'kind':'death-particle-emit-stub','count':r1});self.ret(1);return
  super().hook(u,a,size,data)
 def prepare_damage_context(self,price=4,upgrade=0,mode=0):
  u=self.u;self.upgrade=upgrade;room=self.word(E+0x2b8);assert room==E+0x1000,hex(room)
  u.mem_write(E+0x3000+0x1c,I(price));u.mem_write(room+0x2d4,I(E+0x18b000));u.mem_write(E+0x18b014,I(mode));u.mem_write(room+0x2e0,I(1));u.mem_write(room+0x4bc,I(0));u.mem_write(room+0x334,I(0));u.mem_write(room+0x2f0,I(0));u.mem_write(self.player,bytes(0x100))
  nodes=[n for alias,n in sorted(self.slots.items())]
  if nodes:u.mem_write(E+0x270,I(nodes[0]))
  for i,n in enumerate(nodes):self.next_nodes[n]=nodes[i+1] if i+1<len(nodes) else E+0x268
 def kill(self,owner=1,amount=101,kind=0):
  self.events=[];self.damaging=True
  try:PathProbe.call(self,0x7a62c,[E,owner,BITS(amount),1],[kind])
  finally:self.damaging=False
  room=self.word(E+0x2b8)
  return {'hp_bits':self.word(E+0x140),'state':self.u.mem_read(E+0x170,1)[0],'previous_state':self.u.mem_read(E+0x173,1)[0],'score':self.word(room+0x4bc),'player_kills':self.word(self.player+0x54),'room_kills':self.word(room+0x30),'room_total_kills':self.word(room+0x3c),'remaining_count':self.word(E+0x2b4),'source_cache':SourcePathJoined.source_snapshot(self),'events':self.events.copy()}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();out=Path(args.output);assert not out.exists();p=RewardConstructor();rows=[]
 profiles=[('fresh',(4,4),[(10,10,1)],0,0),('walking',(4,4),[(10,10,1)],0,32),('approaching',(4,4),[(4,7,1)],0,2),('aligned',(10,9),[(10,10,1)],0,64),('two-bases-walking',(4,4),[(10,10,1),(4,12,2)],0,32),('targeted-walking',(4,4),[(10,10,1),(4,12,2)],1,32)]
 specs=[(profile,change,4,level) for profile,change,level in itertools.product(profiles,['open','source','wall','kill-selected'],[0,7])]
 specs += [(profiles[0],'open',price,level) for price,level in itertools.product([0,1,17,1003],[0,1,7,20])]
 for index,(profile,change,price,level) in enumerate(specs):
  pose,start,bases,target,warm=profile;p.input={'source_cell':start,'bases':[{'cell':[x,y],'owner':o,'inactive':False} for x,y,o in bases],'source_owner':0,'source_target':target,'mask':'open'};p.resource_name='creeps/creep5'
  try:
   p.sample(p.resource_name,1,1);constructed=p.snapshot()
   for i in range(warm):Joined.step(p,[0,30,100,16.667,133.333,30,100,100][i%8])
   before_change=p.snapshot();blocked=[];inactive=[]
   if change=='source':blocked=[start]
   if change=='wall':blocked=[(x,7) for x in range(16)]
   if change=='kill-selected' and before_change['base_index']>=0:inactive=[before_change['base_index']]
   for cell in blocked:p.u.mem_write(p.cells[tuple(cell)]+0x18,b'\0')
   for i in inactive:p.u.mem_write(p.base_records[i]+0x5c,F(0));p.u.mem_write(p.base_records[i]+0x6c,b'\1')
   PathProbe.call(p,0xdbbe8,[p.source]);PathProbe.call(p,0x7ace0,[E,0]);p.prepare_damage_context(price,level);before=p.snapshot();after=p.kill();repeated=p.kill()
  except Exception:
   Path('builds/creep-reward-r181-case-'+str(index)+'-failure-trace.json').write_text(json.dumps({'pc':hex(p.u.reg_read(UC_ARM_REG_PC)),'events':p.events,'trace':list(p.reward_trace)},indent=2)+'\n');raise
  rows.append({'input':{**p.input,'pose':pose,'warmup_count':warm,'price':price,'upgrade_level':level,'upgrade_percent':5,'damage_owner':1,'damage_amount':101,'damage_kind':0},'change':{'kind':change,'blocked':blocked,'inactive_base_indices':inactive},'after_constructor':constructed,'before_change':before_change,'before_damage':before,'after_damage':after,'after_repeat':repeated})
  print(json.dumps({'case':index+1,'of':len(specs),'pose':pose,'change':change,'price':price,'upgrade_level':level,'reward':after['score']}),flush=True)
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
