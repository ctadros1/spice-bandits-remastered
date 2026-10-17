"""R164 bounded original movement hover tail plus full state selection.
Movement0x7cfb2..0x7d052 (160bytes) executes with supplied actor in r6,
float32 delta in s16, raw flags348/349/34a, phase344 and animator offset58.
External sinf is an explicit recording stub: math.sin on supplied float32,
rounded to float32. No original libm/GPU or rest of movement/pathfinder runs.
Separate sequences call full original SetState112/SetHover92 before each
bounded hover slice. Actor/map/room construction, ProcessFly and full position
updates are omitted; offset58 is a supplied retained accumulator.
"""
from native_creep_reference import *
import math,itertools
class Hover(Probe):
 def __init__(self):
  super().__init__();self.bodies={a:bytes(self.u.mem_read(a,n)) for a,n in [(0x7cfb2,160),(0x798ec,112),(0x7e870,92)]};self.calls=[]
 def hook(self,u,a,size,data):
  if a==0x36c88c:
   v=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0];out=BITS(math.sin(v));self.calls.append({'input_bits':BITS(v),'output_bits':out});self.ret(out);return
  super().hook(u,a,size,data)
 def prepare(self,h348,h349,active,phase,y):
  u=self.u;u.mem_write(E,bytes(0x4000));u.mem_write(E+0x348,bytes([h348,h349,active]));u.mem_write(E+0x344,F(phase));u.mem_write(E+0x58,F(y))
 def state(self,value):
  u=self.u;self.stop=END;u.reg_write(UC_ARM_REG_SP,STACK-0x1000);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,value);u.emu_start(0x798ed,END,count=20000);assert u.reg_read(UC_ARM_REG_PC)==END
 def step(self,delta):
  u=self.u;self.calls=[];self.stop=0x7d052;u.reg_write(UC_ARM_REG_R6,E);u.reg_write(UC_ARM_REG_S16,BITS(delta));u.reg_write(UC_ARM_REG_SP,STACK-0x1000);u.emu_start(0x7cfb3,self.stop,count=20000);assert u.reg_read(UC_ARM_REG_PC)==self.stop and all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  return {'state':u.mem_read(E+0x170,1)[0],'hover34a':u.mem_read(E+0x34a,1)[0],'phase_bits':struct.unpack('<I',u.mem_read(E+0x344,4))[0],'offset_y_bits':struct.unpack('<I',u.mem_read(E+0x58,4))[0],'sinf_stub':self.calls.copy()}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-hover-reference.json');args=parser.parse_args();p=Hover();cases=[]
 for h348,h349,active,phase,delta,y in itertools.product([0,1],[0,1],[0,1],[-1,0,.5,3.1415927,6.2831855,7],[0,.1,16.667,30,100,5500],[0,5,-40]):
  p.prepare(h348,h349,active,phase,y);cases.append({'input':{'hover348':h348,'hover349':h349,'hover34a':active,'phase':phase,'delta':delta,'offset_y':y},'after':p.step(delta)})
 constructors=json.load(open('tests/fixtures/native-creep-state-reference.json'))['constructors'];sequences=[]
 for c in constructors:
  if c['map_field8']!=1 or c['resource_kind']!=1:continue
  for delta in [16.667,30,100]:
   p.prepare(c['hover348'],c['hover349'],0,0,0);frames=[]
   for frame in range(240):
    state=0 if frame<60 or frame>=180 else (7 if frame<120 else 4);p.state(state);frames.append({'frame':frame,'requested_state':state,'after':p.step(delta)})
   sequences.append({'resource':c['resource'],'delta':delta,'hover348':c['hover348'],'hover349':c['hover349'],'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'body_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'original_unchanged':True,'cases':cases,'sequences':sequences};path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sequences':len(sequences),'frames':sum(len(c['frames']) for c in sequences),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
