"""R167 full original creep Update/ProcessSpeed/ProcessFreeze/movement/position.
Supplied walking actor/resource/map and shared freeze countdown; full original
state/hover selector and UseFreeze execute. The real Update call order is
retained. Dying, bubble, Disco, particles, fly, portal and growth subsystems
are explicit recording stubs, not implemented framework/game behavior.
Straight route/cell/animation-name and C++ exception frame callbacks remain
R166 stubs. External sinf is supplied float32 math.sin output, not original
libm. No actor constructor, room clock/countdown producer, renderer/audio/GPU.
"""
from native_creep_hover_movement_reference import *
class Owner(FullMovement):
 def __init__(self):
  super().__init__();self.owner_calls=[];functions=json.load(open('original/analysis/functions.json'))
  for a in [0x7e8d0,0x7a924,0x7bc1c,0x7bc3c]:self.bodies[a]=bytes(self.u.mem_read(a,next(r['size'] for r in functions if r['address']==a)))
 def hook(self,u,a,size,data):
  functions={0x7a924:'ProcessSpeed-full',0x7bc3c:'ProcessFreeze-full',0x7bfa8:'Movement-full',0x7d108:'Position-full'}
  if a in functions:self.owner_calls.append(functions[a])
  omitted={0x7beb8:'Dying-stub',0xfd8a4:'Bubble-stub',0x7bbc0:'Disco-stub',0x7bce4:'Particles-stub',0x7ead0:'Fly-stub',0x7ee94:'Portal-stub',0x7f058:'Grow-stub'}
  if a in omitted:self.owner_calls.append(omitted[a]);self.ret(0);return
  super().hook(u,a,size,data)
 def invoke(self,address,args):
  u=self.u;self.stop=END;u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2],args):u.reg_write(reg,value)
  u.emu_start(address|1,END,count=200000);assert u.reg_read(UC_ARM_REG_PC)==END
 def run(self,h348,h349,speed,held,delta):
  self.prepare_actor(h348,h349);u=self.u;u.mem_write(E+0x140,F(100));u.mem_write(E+0x144,I(100));u.mem_write(E+0x250,I(E+0x1000));u.mem_write(E+0x1014,I(speed));u.mem_write(E+0x228,F(1));u.mem_write(E+0x22c,F(1));u.mem_write(E+0x2a8,F(100000));counter=E+0x3000;u.mem_write(counter,I(1000));self.state(0)
  if held:self.invoke(0x7bc1c,[E,counter])
  rows=[]
  for frame,count in enumerate([1000,1000,1,0,0,0,0,0]):
   u.mem_write(counter,I(count));u.mem_write(E+0x230,F(-1));self.owner_calls=[];self.calls=[];self.position_calls=0;self.movement_mode=True
   target=struct.unpack('<2f',u.mem_read(E+0x180,8));self.future=(target[0],target[1]+100)
   self.invoke(0x7e8d0,[E,BITS(delta),0]);word=lambda offset:struct.unpack('<I',u.mem_read(E+offset,4))[0]
   assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
   rows.append({'frame':frame,'supplied_counter':count,'calls':self.owner_calls.copy(),'freeze_attached':bool(word(0x20c)),'freeze_remaining':word(0x208),'primary_multiplier_bits':word(0x70),'speed_bits':word(0x224),'state':u.mem_read(E+0x170,1)[0],'hover_active':u.mem_read(E+0x34a,1)[0],'phase_bits':word(0x344),'animator_position_bits':[word(0x4c),word(0x50)],'offset_bits':[word(0x54),word(0x58)],'logical_position_bits':[word(0x188),word(0x18c)],'full_position_calls':self.position_calls,'sinf_stub':self.calls.copy()})
  return rows
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=Owner();cases=[]
 for flags,speed,held,delta in itertools.product([(0,0),(1,0),(1,1)],[0,1000],[False,True],[0,16.667,30,100]):
  rows=p.run(*flags,speed,held,delta);cases.append({'input':{'hover348':flags[0],'hover349':flags[1],'speed':speed,'freeze':held,'delta':delta},'frames':rows})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':cases}
 path=Path(args.output);path.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
