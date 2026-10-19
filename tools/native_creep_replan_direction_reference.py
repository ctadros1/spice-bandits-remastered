"""R176 original normal rerouting with complete direction and conversion helpers.
Extends the R175 full original A*/base/reroute/movement join by executing full
UpdateDirection, UpdateDirectionBlendingAnimator, GetDirFixFloatinPoint,
GetAnimationFromDir, ConvertDirections and ismatch. Resource5's raw direction
flag1 and animator defaults are explicit supplied constructor-derived inputs.
Animator Play/GetName and shooting-direction remain recording/name stubs;
AngPos, sinf/floorf and sound retain the earlier explicit callbacks. Names and
rotation/alpha fields are compared only for nonaligned walking state0, without
claiming shooting orientation, animation clocks, original graph/resource/actor
initialization, full owner scheduling, audio backend or GPU identity.
"""
from native_creep_replan_reference import *
class DirectionJoined(ReplanJoined):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0x7acac,0x7f32c,0x7f150,0x7f1f0,0x79f30,0x122020]:
   self.actual.append(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
 def setup_full(self,pose,base,mask):
  blocked=super().setup_full(pose,base,mask);u=self.u;u.mem_write(E+0x38,b'\1');u.mem_write(E+0x22c,F(1));u.mem_write(E+0x80,F(1));u.mem_write(E+0xf4,F(0));return blocked
 def snapshot(self):
  row=super().snapshot();u=self.u
  row['walking_animator']={'primary':self.names.get(E+0x4c,''),'secondary':self.names.get(E+0xc0,''),'rotation_bits':struct.unpack('<I',u.mem_read(E+0x7c,4))[0],'alpha_bits':struct.unpack('<I',u.mem_read(E+0x80,4))[0],'secondary_rotation_bits':struct.unpack('<I',u.mem_read(E+0xf0,4))[0],'secondary_alpha_bits':struct.unpack('<I',u.mem_read(E+0xf4,4))[0]}
  return row
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=DirectionJoined();rows=[]
 for pose,base,mask in itertools.product(['walking-early','walking-late','waiting','approaching','aligned'],[(4,7),(4,10)],['open','current','next','both']):
  blocked=p.setup_full(pose,base,mask);before=p.snapshot();p.invoke(0x7ace0,[E,0]);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100,100,100,100,100]):p.step(dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{'pose':pose,'base_cell':base,'blocked':blocked,'resource':'creeps/creep5','base_distance':2,'speed':1000,'supplied_rof':1000000,'owner':9001,'geometry':{'base':44,'side':22,'height':64,'offset_x':0,'offset_y':0},'map_width':16,'map_height':16,'raw_bomber':False,'raw_laser':False,'raw_kamikaze':False,'direction_interpolation':1},'before':before,'after_replan':after,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'movement_frames':sum(len(x['frames']) for x in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
