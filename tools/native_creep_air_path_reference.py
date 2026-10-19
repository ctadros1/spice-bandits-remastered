"""R182 original ordinary-plane C2/source/movement/reroute/reward join.
Full original resource4/kind2 constructor, source caches/A*, normal movement,
state/hover/position/direction, source-aware reroute, DoDamage/SetDie execute.
Graph/resources/room/player records are supplied. R181 parameter/string/tree/
allocation/registry/random/texture/zero-AngPos/float32 math/shooting/audio/
zero-base-damage callbacks remain explicit. Full room/resource/graph/player
producers, missile/particle Emit/backend/GPU, complete death chronology and
shooting primary names after omitted direction callback remain unproven.
"""
from native_creep_reward_reference import *
class PlaneConstructor(RewardConstructor):
 def __init__(self):
  self.constructor_arguments=[];super().__init__()
 def hook(self,u,a,size,data):
  if a==0x78374:self.constructor_arguments.append([u.reg_read(UC_ARM_REG_R2),u.reg_read(UC_ARM_REG_R3)])
  if a in [0x7b0ce,0x7b1b0,0x7b24c]:self.events.append({'kind':'source-replan-branch','address':hex(a)})
  super().hook(u,a,size,data)
 def prepare_constructor_context(self):
  super().prepare_constructor_context();self.u.reg_write(UC_ARM_REG_R2,self.input['creep_number']);self.u.mem_write(E+0x3014,I(self.input['speed']))
 def snapshot(self):
  row=super().snapshot();row['previous_state']=self.u.mem_read(E+0x172,1)[0];row['target_owner']=self.word(E+0x164);return row

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);parser.add_argument('--limit',type=int,default=0);args=parser.parse_args();out=Path(args.output);assert not out.exists();p=PlaneConstructor();rows=[]
 profiles=[('fresh',(4,4),[(10,10,1)],0,0,0),('walking',(4,4),[(10,10,1)],0,0,32),('approaching',(4,4),[(4,7,1)],0,0,2),('aligned',(10,9),[(10,10,1)],0,0,64),('targeted-walking',(4,4),[(10,10,1),(4,12,2)],0,1,32),('owned-aligned',(10,9),[(10,10,1),(4,7,2)],1,0,96)]
 specs=[(profile,4,1000,'open',change) for profile,change in itertools.product(profiles,['open','current','next','wall','kill-selected','kill-all'])]
 specs += [(('variant-spawn',(4,4),[(10,10,1)],0,0,0),number,speed,mask,'open') for (number,speed),mask in itertools.product([(4,1200),(22,1200),(23,600),(24,960)],['open','source','wall','inactive'])]
 if args.limit:specs=specs[:args.limit]
 for index,(profile,number,speed,mask,change) in enumerate(specs):
  pose,start,bases,owner,target,warm=profile;p.input={'source_cell':start,'bases':[{'cell':[x,y],'owner':o,'inactive':mask=='inactive'} for x,y,o in bases],'source_owner':owner,'source_target':target,'mask':mask if mask!='inactive' else 'open','initial_label':mask,'creep_number':number,'speed':speed};p.resource_name='creeps/creep4';p.constructor_arguments=[]
  try:
   p.sample(p.resource_name,1,2);assert p.constructor_arguments==[[number,9001]];assert p.word(p.word(E+0x250)+4)==2;constructed=p.snapshot();warmup=[]
   for i in range(warm):dt=[0,30,100,16.667,133.333,30,100,100][i%8];Joined.step(p,dt);warmup.append({'frame':i,'delta':dt,'after':p.snapshot()})
   before=p.snapshot();source_before=SourcePathJoined.source_snapshot(p)
   if pose=='approaching':assert before['state']==4 and before['aligned']==0
   if pose.endswith('aligned'):assert before['state']==4 and before['aligned']==1
   if pose.endswith('walking') or pose=='fresh':assert before['state']==0 and before['aligned']==0
   blocked=[];inactive=[]
   if change=='current':blocked=[tuple(before['cell'])]
   if change=='next':blocked=[tuple(before['next_cell'])]
   if change=='wall':blocked=[(x,7) for x in range(16)]
   if change=='kill-selected' and before['base_index']>=0:inactive=[before['base_index']]
   if change=='kill-all':inactive=list(range(len(bases)))
   for cell in blocked:p.u.mem_write(p.cells[tuple(cell)]+0x18,b'\0')
   for i in inactive:p.u.mem_write(p.base_records[i]+0x5c,F(0));p.u.mem_write(p.base_records[i]+0x6c,b'\1')
   PathProbe.call(p,0xdbbe8,[p.source]);source_after=SourcePathJoined.source_snapshot(p);p.events=[];PathProbe.call(p,0x7ace0,[E,0]);after=p.snapshot();frames=[]
   for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100]*3):Joined.step(p,dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
   p.prepare_damage_context(3,7);room=p.word(E+0x2b8);p.u.mem_write(room+0x2a8,I(p.player));p.u.mem_write(p.player+0x20,I(200));death_before=p.snapshot();dead=p.kill();dead['local_player_money']=p.word(p.player+0x20);repeated=p.kill();repeated['local_player_money']=p.word(p.player+0x20)
  except Exception:
   Path('builds/creep-air-r182-case-'+str(index)+'-failure-trace.json').write_text(json.dumps({'pc':hex(p.u.reg_read(UC_ARM_REG_PC)),'input':p.input,'events':p.events,'trace':list(p.reward_trace)},indent=2)+'\n');raise
  rows.append({'input':{**p.input,'pose':pose,'warmup_count':warm,'price':3,'upgrade_level':7,'initial_money':200},'change':{'kind':change,'blocked':blocked,'inactive_base_indices':inactive},'after_constructor':constructed,'warmup_frames':warmup,'before_change':before,'source_cache_before':source_before,'source_cache_after':source_after,'after_replan':after,'frames':frames,'before_damage':death_before,'after_damage':dead,'after_repeat':repeated})
  print(json.dumps({'case':index+1,'of':len(specs),'pose':pose,'number':number,'initial':mask,'change':change,'state':after['state'],'pending':len(after['path']),'reward':dead['score']}),flush=True)
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(rows),'warmup_frames':sum(len(r['warmup_frames']) for r in rows),'after_change_frames':sum(len(r['frames']) for r in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
