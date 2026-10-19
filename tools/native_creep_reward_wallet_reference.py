"""Additional original full DoDamage/SetDie with a nonnull local-player record.
The room+0x2a8 local-player pointer and its +0x20 currency counter are supplied;
full original instructions add the computed reward there. This complements the
64 score/route cases whose local-player pointer is null. Full C2/source/reroute
and DoDamage/SetDie run; parent resource/player/room/backend callbacks remain
explicit and are not full original producers/Objective-C services/GPU identity.
"""
import sys,argparse
sys.path.insert(0,'tools')
from native_creep_reward_reference import *
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args();out=Path(args.output);assert not out.exists();p=RewardConstructor();rows=[]
 for price,level,initial in [(4,0,200),(4,7,200),(17,1,37),(0,0,0)]:
  p.input={'source_cell':(4,4),'bases':[{'cell':[10,10],'owner':1,'inactive':False}],'source_owner':0,'source_target':0,'mask':'open'};p.resource_name='creeps/creep5';p.sample(p.resource_name,1,1);PathProbe.call(p,0xdbbe8,[p.source]);PathProbe.call(p,0x7ace0,[E,0]);p.prepare_damage_context(price,level)
  room=p.word(E+0x2b8);p.u.mem_write(room+0x2a8,I(p.player));p.u.mem_write(p.player+0x20,I(initial));before=p.snapshot();after=p.kill();after['local_player_money']=p.word(p.player+0x20);repeat=p.kill();repeat['local_player_money']=p.word(p.player+0x20);assert after['local_player_money']==initial+after['score'] and repeat['local_player_money']==after['local_player_money'];rows.append({'input':{**p.input,'price':price,'upgrade_level':level,'initial_money':initial},'before_damage':before,'after_damage':after,'after_repeat':repeat})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 out.write_text(json.dumps({'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'cases':rows},indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
