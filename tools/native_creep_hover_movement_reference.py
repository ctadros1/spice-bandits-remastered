"""R166 full original movement/position/state/hover on supplied walking records.
UpdateMovementAndShooting, UpdatePosition, SetState and hover selector execute
unchanged. Straight path/cell/animation-name callbacks and C++ exception-frame
registration are explicit stubs, with no base/attack target, shooting processor,
laser beam or missiles. Resource flags come from the separately executed R163
constructors. Map/room/actor allocation and full original route/RNG are omitted.
External sinf remains an explicit float32 math.sin output stub, not original
libm. No renderer/audio/GPU runs. This joins the earlier isolated hover tail
to its real movement/position caller without claiming the whole game.
"""
from native_creep_hover_reference import *
from collections import deque
class FullMovement(Hover):
 def __init__(self):
  super().__init__();self.trace=deque(maxlen=60);self.position_calls=0
  functions=json.load(open('original/analysis/functions.json'))
  for a in [0x7bfa8,0x7d108]:self.bodies[a]=bytes(self.u.mem_read(a,next(r['size'] for r in functions if r['address']==a)))
 def hook(self,u,a,size,data):
  self.trace.append(hex(a))
  if a==0x36ca7c:self.ret();return # C++ exception frame unregister
  if a==0x7d108:self.position_calls+=1;return # full original UpdatePosition
  super().hook(u,a,size,data)
 def prepare_actor(self,h348,h349):
  self.prepare(h348,h349,0,0,0);u=self.u
  self.point(E+0x1a0,(100,100));self.point(E+0x180,(100,200));self.point(E+0x188,(100,150))
  u.mem_write(E+0x158,F(.5));u.mem_write(E+0x224,F(1000));u.mem_write(E+0x2a0,b'\x01');u.mem_write(E+0x2a3,b'\x01')
  u.mem_write(E+0x1c,I(E+0x600));u.mem_write(E+0x674,I(E+0x700));u.mem_write(0x40a1ec,I(MEMORY+9000));u.mem_write(MEMORY+9000,F(64))
 def frame(self,state,delta):
  self.state(state);self.calls=[];self.position_calls=0;self.stop=END;self.movement_mode=True
  target=struct.unpack('<2f',self.u.mem_read(E+0x180,8));self.future=(target[0],target[1]+100)
  u=self.u;u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,BITS(delta));u.reg_write(UC_ARM_REG_R2,0)
  try:u.emu_start(0x7bfa9,END,count=100000)
  except Exception:print(json.dumps({'last_addresses':list(self.trace),'pc':hex(u.reg_read(UC_ARM_REG_PC))}),flush=True);raise
  assert u.reg_read(UC_ARM_REG_PC)==END and all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  word=lambda offset:struct.unpack('<I',u.mem_read(E+offset,4))[0]
  return {'state':u.mem_read(E+0x170,1)[0],'hover_active':u.mem_read(E+0x34a,1)[0],'phase_bits':word(0x344),'animator_position_bits':[word(0x4c),word(0x50)],'animator_offset_bits':[word(0x54),word(0x58)],'logical_position_bits':[word(0x188),word(0x18c)],'progress_bits':word(0x158),'full_position_calls':self.position_calls,'sinf_stub':self.calls.copy()}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=FullMovement();sequences=[]
 for row in json.load(open('tests/fixtures/native-creep-state-reference.json'))['constructors']:
  if row['map_field8']!=1 or row['resource_kind']!=1:continue
  for delta in [16.667,30,100]:
   p.prepare_actor(row['hover348'],row['hover349']);frames=[]
   for i in range(240):
    state=0 if i<60 or i>=180 else (7 if i<120 else 4)
    frames.append({'frame':i,'requested_state':state,'after':p.frame(state,delta)})
   sequences.append({'resource':row['resource'],'hover348':row['hover348'],'hover349':row['hover349'],'delta':delta,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'original_unchanged':True,'sequences':sequences}
 path=Path(args.output);path.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'sequences':len(sequences),'frames':sum(len(r['frames']) for r in sequences),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
