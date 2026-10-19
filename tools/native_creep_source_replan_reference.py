"""R180 original source-linked existing-actor rerouting and selected target loss.

Extends R179 full constructor/source-cache/normal movement on supplied16x16
graph/resources/source/base records. Existing poses arise from actual original
constructor and movement, not manually selected states. Full source refresh and
UpdateShortestPath run after explicit walk/base-active changes. Original code
bytes remain unchanged. R179 resource/registry/texture/name/random/heading/math/
shooting/audio/zero-base-damage callbacks remain explicit; full game production,
animation/backend/GPU identity, other resources and combat/reward consumers are
not established by this join.
"""
from native_creep_spawn_path_reference import *

class SourceReplanConstructor(SpawnPathConstructor):
 def hook(self,u,a,size,data):
  if a in [0x7b0ce,0x7b1b0,0x7b24c]:self.events.append({'kind':'source-replan-branch','address':hex(a)})
  super().hook(u,a,size,data)
 def snapshot(self):
  row=super().snapshot();row['previous_state']=self.u.mem_read(E+0x172,1)[0];row['target_owner']=self.word(E+0x164);return row

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=SourceReplanConstructor();rows=[]
 profiles=[
  ('fresh',(4,4),[(10,10,1)],0,0,0),
  ('walking',(4,4),[(10,10,1)],0,0,32),
  ('approaching',(4,4),[(4,7,1)],0,0,2),
  ('aligned',(10,9),[(10,10,1)],0,0,64),
  ('two-bases-walking',(4,4),[(10,10,1),(4,12,2)],0,0,32),
  ('two-bases-aligned',(10,9),[(10,10,1),(4,7,2)],0,0,64),
  ('targeted-walking',(4,4),[(10,10,1),(4,12,2)],0,1,32),
  ('owned-aligned',(10,9),[(10,10,1),(4,7,2)],1,0,96)]
 for (pose,start,bases,owner,target,warm),change in itertools.product(profiles,['open','current','next','both','wall','kill-selected','kill-all']):
  p.input={'source_cell':start,'bases':[{'cell':[x,y],'owner':o,'inactive':False} for x,y,o in bases],'source_owner':owner,'source_target':target,'mask':'open'};p.resource_name='creeps/creep5';p.sample(p.resource_name,1,1);constructed=p.snapshot();warmup=[]
  for i in range(warm):dt=[0,30,100,16.667,133.333,30,100,100][i%8];Joined.step(p,dt);warmup.append({'frame':i,'delta':dt,'after':p.snapshot()})
  before=p.snapshot()
  if pose=='approaching':assert before['state']==4 and before['aligned']==0,(pose,before)
  if pose.endswith('aligned'):assert before['state']==4 and before['aligned']==1,(pose,before)
  if pose.endswith('walking') or pose=='fresh':assert before['state']==0 and before['aligned']==0,(pose,before)
  source_before=SourcePathJoined.source_snapshot(p);blocked=[];inactive=[]
  if change in ['current','both']:blocked.append(tuple(before['cell']))
  if change in ['next','both']:blocked.append(tuple(before['next_cell']))
  if change=='wall':blocked=[(x,7) for x in range(16)]
  blocked=list(dict.fromkeys(blocked))
  for cell in blocked:p.u.mem_write(p.cells[cell]+0x18,b'\0')
  if change=='kill-selected' and before['base_index']>=0:inactive=[before['base_index']]
  if change=='kill-all':inactive=list(range(len(bases)))
  for i in inactive:p.u.mem_write(p.base_records[i]+0x5c,F(0));p.u.mem_write(p.base_records[i]+0x6c,b'\1')
  PathProbe.call(p,0xdbbe8,[p.source]);source_after=SourcePathJoined.source_snapshot(p);p.events=[];PathProbe.call(p,0x7ace0,[E,0]);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100]*3):Joined.step(p,dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{**p.input,'pose':pose,'warmup_count':warm},'change':{'kind':change,'blocked':blocked,'inactive_base_indices':inactive},'after_constructor':constructed,'warmup_frames':warmup,'before_change':before,'source_cache_before':source_before,'source_cache_after':source_after,'after_replan':after,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(rows),'warmup_frames':sum(len(r['warmup_frames']) for r in rows),'after_change_frames':sum(len(r['frames']) for r in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
