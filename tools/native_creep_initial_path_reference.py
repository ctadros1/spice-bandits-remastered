"""R178 complete original segment initializer and portal transfer with real A*.

Extends the R177 supplied16x16 graph/actor/base join. Full UpdatePosition(iiiif),
GetCenterOfCell, InterpolateVectors2D and TeleportCreep now execute unchanged;
the initializer is not a supplied-path stub. Actor records still start at
explicit R175 poses, not from the complete room/AddCreep constructor chain.
Original graph/resource producers, external math, animator/audio backend, GPU,
all faction/target-loss/special paths and whole-game scheduling remain outside
this evidence. Record initial/pending counts and pre-hover aim without assuming
their eventual reward/target caller semantics.
"""
from native_creep_replan_direction_reference import *

class InitialPathJoined(DirectionJoined):
 def __init__(self):
  super().__init__();fs=json.load(open('original/analysis/functions.json'))
  for a in [0x7aaac,0x10b614,0x1107e8,0x9c2c8]:
   self.actual.append(a);self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
 def hook(self,u,a,size,data):
  if a==0x7ba04:
   self.events.append({'kind':'GetFirstMovementPoint-full','pop':struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_SP),4))[0]})
  if a==0x7aaac:self.events.append({'kind':'UpdatePosition-iiiif-full'})
  if a==0x9c2c8:self.events.append({'kind':'TeleportCreep-full'})
  super().hook(u,a,size,data)
 def snapshot(self):
  row=super().snapshot();u=self.u
  word=lambda o:struct.unpack('<I',u.mem_read(E+o,4))[0]
  row.update({'aim_bits':[word(0x190),word(0x194)],'secondary_position_bits':[word(0xc0),word(0xc4)],'raw_hit_pending':u.mem_read(E+0x2b0,1)[0],'remaining_count':word(0x2b4),'previous_progress_bits':word(0x15c),'position_flags':list(u.mem_read(E+0x2a0,5)),'segment_relation':u.mem_read(E+0x358,1)[0],'portal_state':word(0x354),'portal_clock_bits':word(0x350),'portal_marker':list(struct.unpack('<2i',u.mem_read(E+0x168,8)))})
  return row
 def initialize_segment(self,start,end,progress):
  self.events=[];self.invoke(0x7aaac,[E,*start,end[0]],[end[1],BITS(progress)])
 def teleport(self,exit_cell):
  self.events=[];u=self.u;portal=E+0x10000;exit_record=E+0x10100
  u.mem_write(portal+0x64,I(E+0x1000));u.mem_write(portal+0x7c,I(exit_record));u.mem_write(exit_record+0x44,struct.pack('<2i',*exit_cell))
  self.invoke(0x9c2c8,[portal,E])

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=InitialPathJoined();rows=[]
 specs=[('same', (4,4),(4,5)),('reversed',(4,5),(4,4)),('shifted',(6,4),(6,5)),('collapsed',(6,4),(6,4))]
 for pose,base,(relation,start,end),progress in itertools.product(['walking-early','approaching','aligned'],[(10,10)],specs,[0,.25,1,1.25]):
  p.setup_full(pose,base,'open');p.point(E+0x1c8,(2.75,-3.5));before=p.snapshot();p.initialize_segment(start,end,progress);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100]):p.step(dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{'operation':'initialize','pose':pose,'base_cell':base,'blocked':[],'resource':'creeps/creep5','base_distance':2,'speed':1000,'supplied_rof':1000000,'owner':9001,'start':start,'end':end,'progress':progress,'relation':relation,'jitter':[2.75,-3.5],'direction_interpolation':1},'before':before,'after_operation':after,'frames':frames})
 for pose,base,exit_cell in itertools.product(['walking-early','approaching','aligned'],[(10,10)],[(0,0),(6,4),(10,9),(10,10)]):
  p.setup_full(pose,base,'open');p.point(E+0x1c8,(2.75,-3.5));before=p.snapshot();p.teleport(exit_cell);after=p.snapshot();frames=[]
  for i,dt in enumerate([0,30,100,16.667,133.333,30,100,100]*8):p.step(dt);frames.append({'frame':i,'delta':dt,'after':p.snapshot()})
  rows.append({'input':{'operation':'teleport','pose':pose,'base_cell':base,'blocked':[],'resource':'creeps/creep5','base_distance':2,'speed':1000,'supplied_rof':1000000,'owner':9001,'exit_cell':exit_cell,'jitter':[2.75,-3.5],'direction_interpolation':1},'before':before,'after_operation':after,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'movement_frames':sum(len(x['frames']) for x in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
