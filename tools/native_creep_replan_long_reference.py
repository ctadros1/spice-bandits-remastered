"""R177 long original reroute/direction/turn/movement sequences on supplied grids.
The full R175/R176 original caller, A*, smoothing, base and direction helpers
execute over192 changing-time frames after each actual original reroute. Far
bases and supplied blocked endpoints force multiple turns and eventual approach.
Approach records supply coherent float32 logical positions for both axes.
Animator Play/GetName, shooting orientation, AngPos, libm and audio retain the
explicit callbacks described by R176; whole original construction/scheduling,
graph/resource producers, target loss, special actors and GPU remain outside.
"""
from native_creep_replan_direction_reference import *
class LongJoined(DirectionJoined):
 def setup_full(self,pose,base,mask):
  blocked=super().setup_full(pose,base,mask)
  if pose=='approaching':
   point=struct.unpack('<2f',self.u.mem_read(E+0x23c,8));logical=(308+(point[0]-308)*.25,352+(point[1]-352)*.25);self.point(E+0x188,logical);self.point(E+0x4c,logical);self.point(E+0xc0,logical)
  return blocked
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=LongJoined();rows=[]
 for pose,base,mask in itertools.product(['walking-early','waiting','approaching','aligned'],[(10,10),(14,14)],['open','next']):
  blocked=p.setup_full(pose,base,mask);before=p.snapshot();p.invoke(0x7ace0,[E,0]);after=p.snapshot();frames=[]
  for i,dt in enumerate([16.667,30,100,133.333]*48):p.step(dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{'pose':pose,'base_cell':base,'blocked':blocked,'resource':'creeps/creep5','base_distance':2,'speed':1000,'supplied_rof':1000000,'owner':9001,'geometry':{'base':44,'side':22,'height':64,'offset_x':0,'offset_y':0},'map_width':16,'map_height':16,'raw_bomber':False,'raw_laser':False,'raw_kamikaze':False,'direction_interpolation':1},'before':before,'after_replan':after,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'movement_frames':sum(len(x['frames']) for x in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
