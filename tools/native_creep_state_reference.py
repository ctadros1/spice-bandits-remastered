"""R163 full original SetState/SetHover selected fields and constructor flags.
SetState112/SetHover92 execute on supplied old/new states, two raw hover flags,
initial hover byte7, smoke pointer/multiplier/interval and sound-pointer flags.
CSound.Stop is a recording stub; no original audio backend or room/game/GPU.
Separate full R149 constructor/factory/PS.C2/SetState chain now also executes
SetHover; all R149 supplied parameter/header/resource/string/map/new/texture
callbacks and omissions still apply. No ProcessHover/movement/pathfinder.
"""
from native_creep_particle_constructor_reference import *
import itertools,argparse
class State(Probe):
 def __init__(self):
  super().__init__();self.bodies={a:bytes(self.u.mem_read(a,n)) for a,n in [(0x798ec,112),(0x7e870,92)]};self.calls=[]
 def hook(self,u,a,size,data):
  if a==0x11f75c:self.calls.append('CSound.Stop-stub');self.ret();return
  super().hook(u,a,size,data)
 def sample(self,old,new,h348,h349,smoke,multiplier,sound):
  u=self.u;u.mem_write(E,bytes(0x4000));u.mem_write(E+0x170,bytes([old]));u.mem_write(E+0x348,bytes([h348,h349,7]));u.mem_write(E+0x2c8,I(E+0x1000 if smoke else 0));u.mem_write(E+0x2e4,F(multiplier));u.mem_write(E+0x2e8,F(.3));u.mem_write(E+0x27c,I(0 if sound is None else E+0x2000));u.mem_write(E+0x2016,bytes([sound or 0]));self.calls=[];u.reg_write(UC_ARM_REG_SP,STACK-0x1000);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,new);u.emu_start(0x798ed,END,count=20000);assert u.reg_read(UC_ARM_REG_PC)==END
  assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  return {'input':{'old':old,'new':new,'hover348':h348,'hover349':h349,'initial_hover34a':7,'smoke_present':smoke,'smoke_multiplier':multiplier,'interval_bits':BITS(.3),'sound_flags':sound},'after':{'state':u.mem_read(E+0x170,1)[0],'hover34a':u.mem_read(E+0x34a,1)[0],'interval_bits':struct.unpack('<I',u.mem_read(E+0x2e8,4))[0]},'calls':self.calls.copy()}
class FullStateConstructor(Constructor):
 def __init__(self):
  super().__init__();self.bodies[0x7e870]=bytes(self.u.mem_read(0x7e870,92))
 def hook(self,u,a,size,data):
  if a==0x7e870:return
  super().hook(u,a,size,data)
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-state-reference.json');args=parser.parse_args();p=State();cases=[p.sample(*x) for x in itertools.product(range(8),range(8),[0,1],[0,1],[False,True],[0,.12,2],[None,0,1])];c=FullStateConstructor();constructors=[]
 for number in range(1,11):
  for theme in [1,2]:
   for kind in [1,2]:
    row=c.sample('creeps/creep'+str(number),theme,kind);constructors.append({'resource':row['resource'],'map_field8':theme,'resource_kind':kind,'hover348':c.u.mem_read(E+0x348,1)[0],'hover349':c.u.mem_read(E+0x349,1)[0],'hover34a':c.u.mem_read(E+0x34a,1)[0],'smoke_idle_multiplier_bits':c.word(E+0x2e4),'smoke_work_interval_bits':c.word(E+0x2e8),'parameter_requests':row['param_calls']})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA and all(bytes(c.u.mem_read(a,len(b)))==b for a,b in c.bodies.items())
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'state_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'constructor_chain_function_bytes':{hex(a):len(b) for a,b in c.bodies.items()},'original_unchanged':True,'cases':cases,'constructors':constructors};path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'constructors':len(constructors),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
