"""R174 variable-time extension of the full original normal approach join.
The R174 Joined unchanged original bodies execute with supplied geometry,
speed, progress, carry and changing frame times. Hover/offset/smoke fields
come from separately executed constructors. Bomber/laser/kamikaze raw flags
remain explicitly zero, and reload is too long to shoot. The path builder,
original map/actor initialization, animation/direction/sound backends, libm,
owner scheduling and GPU remain outside this supplied-record comparison.
This covers 72 selected combinations, not every Cartesian input combination.
"""
from native_creep_approach_reference import *

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args()
 p=Joined();constructors=json.load(open('tests/fixtures/native-creep-state-reference.json'))['constructors'];params=json.load(open('game/data/catalog.json'))['resource_params'];cases=[]
 for height,number,speed_index,progress_index in itertools.product([48,64],[1,5,6],range(4),range(3)):
  speed=[0,250,1000,5000][speed_index];progress=[.125,.99,1][progress_index];carry=[0,.018,.3][progress_index];count=[0,2,5][(speed_index+progress_index)%3];base=(4,7) if speed_index%2 else (10,10);stand_off=2 if progress_index%2 else 4
  resource='creeps/creep'+str(number);c=next(x for x in constructors if x['resource']==resource and x['map_field8']==1 and x['resource_kind']==1);p.setup(count,base,progress,(c['hover348'],c['hover349']),stand_off);u=p.u
  for (x,y),cell in p.cells.items():p.point(cell+0x10,(44+x*66,height/2+y*height+(x%2)*height/2))
  world=lambda cell:struct.unpack('<2f',u.mem_read(p.cells[cell]+0x10,8))
  start,target=world((4,4)),world((4,5));p.point(E+0x1a0,start);p.point(E+0x180,target);p.point(E+0x188,tuple(start[i]+(target[i]-start[i])*progress for i in range(2)));p.point(E+0x9064,world(base));u.mem_write(E+0x224,F(speed));u.mem_write(E+0x364,F(carry));u.mem_write(MEMORY+9000,F(height));u.mem_write(0x47eda0,F(height))
  offset=params[resource].get('offset',[0,0]);p.point(E+0x54,offset);u.mem_write(E+0x2c8,I(E+0x11000));u.mem_write(E+0x2e4,I(c['smoke_idle_multiplier_bits']));u.mem_write(E+0x2e8,I(c['smoke_work_interval_bits']));u.mem_write(E+0x138,I(9001))
  deltas=[0,16.667,133.333,30,250,0,16.667,100]*3
  frames=[{'frame':i,'delta':dt,'after':p.step(dt)} for i,dt in enumerate(deltas)]
  cases.append({'input':{'resource':resource,'remaining_route':[[4,6+i] for i in range(count)],'base_cell':base,'current_cell':[4,4],'next_cell':[4,5],'progress':progress,'carry':carry,'base_distance':stand_off,'speed':speed,'hex_distance':height,'map_width':16,'map_height':16,'geometry':{'base':44,'side':22,'height':height,'offset_x':0,'offset_y':0},'offset':offset,'hover348':c['hover348'],'hover349':c['hover349'],'smoke_multiplier_bits':c['smoke_idle_multiplier_bits'],'working_interval_bits':c['smoke_work_interval_bits'],'owner':9001,'raw_kamikaze':False,'raw_bomber':False,'raw_laser':False,'supplied_rof':1000000},'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':cases};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(x['frames']) for x in cases),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)

if __name__=='__main__':main()
