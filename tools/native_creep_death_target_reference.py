"""Full original IsAnyCreepTargetedForPlayer with supplied creature vector.
Owner/target/state and an empty base-manager vector are explicit inputs.
No HP/particle/death/room/services/constructor/GPU/game executes.
"""
import sys,itertools,json
sys.path.insert(0,'tools')
from native_map_order_reference import *
def main():
 p=OrderProbe();cases=[]
 for state,owner,target in itertools.product(range(8),[0,1,2],[0,1,2]):
  p.reset();u=p.u;actor=E+0x1000;vector=E+0x8000
  u.mem_write(actor+0x160,struct.pack('<2I',owner,target));u.mem_write(actor+0x170,bytes([state]));u.mem_write(0x47ed54,struct.pack('<2I',vector,vector+4));u.mem_write(vector,I(actor));u.mem_write(0x40a110,I(E+0x9000));u.mem_write(E+0x9000,bytes(8));p.invoke(0xfc0c8,[1]);out=u.reg_read(UC_ARM_REG_R0);assert bool(out)==(target in [0,1] and owner!=1)
  cases.append({'state':state,'owner':owner,'target':target,'player':1,'result':bool(out)})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-death-target-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'state2_and3_remain_counted_for_matching_enemy_target':True,'source_unchanged':data['original_unchanged']}))

if __name__=="__main__":main()
