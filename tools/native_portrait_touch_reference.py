"""Original TutorialView touch distance/removal scheduling with explicit points.

NIB/UIView/touch/frame/message operations and CGRectContainsPoint are stubs;
containment is an explicit boolean input, not a CoreGraphics oracle. Original
Began/Moved/Ended instructions execute. Record strict20px float32 distance,
zero-delay removal request, resetting prior point and forwarding intent.
"""
from native_creep_reference import *

class TouchProbe(Probe):
 def __init__(self):
  super().__init__()
  symbols=json.load(open('original/analysis/decrypted-symbols.json'))
  self.offsets={}
  for key in ['previousTouchLocation','passTouchesTo']:
   symbol=next(v for v in symbols if v['name']=='_OBJC_IVAR_$_TutorialView.'+key and v['value'])
   self.offsets[key]=struct.unpack('<I',self.u.mem_read(symbol['value'],4))[0]
  self.u.mem_write(0x40a1b0,I(MEMORY+120000));self.u.mem_write(MEMORY+120000,bytes(8))
 def hook(self,u,a,size,data):
  if a==0x36be6c:
   receiver,sel,arg=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]];name=self.string(sel)
   if name=='performSelector:withObject:afterDelay:':self.remove=self.string(arg)=='removeTutorial'
   elif name.startswith('touches') and receiver:self.forward.append(name)
   self.ret(E+0x1000);return
  if a==0x36be9c:
   out=u.reg_read(UC_ARM_REG_R0);name=self.string(u.reg_read(UC_ARM_REG_R2))
   self.u.mem_write(out,struct.pack('<2f',*self.point_value) if name=='locationInView:' else struct.pack('<4f',0,-5,768,265));self.ret();return
  if a==0x36b0bc:self.ret(int(self.contains));return
  super().hook(u,a,size,data)
 def call(self,addr):
  self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,0,E+0x1000,E+0x2000]):self.u.reg_write(r,v)
  self.u.emu_start(addr|1,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
 def run(self,start,end,contains,forward):
  self.remove=False;self.forward=[];self.contains=contains;self.u.mem_write(E,bytes(0x3000))
  self.u.mem_write(E+self.offsets['passTouchesTo'],I(E+0x2500 if forward else 0))
  self.point_value=start;self.call(0x669d8);self.call(0x66a60)
  self.point_value=end;self.call(0x66a88)
  return {'remove':self.remove,'previous':list(struct.unpack('<2f',self.u.mem_read(E+self.offsets['previousTouchLocation'],8))),'forwarded':self.forward}
probe=TouchProbe();cases=[]
for start in [(30,40),(400,200),(1000000,1000000)]:
 for dx,dy in [(0,0),(19.9,0),(19.999999,0),(20,0),(20.000001,0),(0,-20),(12,16),(14,14),(19,6),(-19.99,0),(1,1)]:
  for contains in [False,True]:
   for forward in [False,True]:
    end=(start[0]+dx,start[1]+dy);cases.append({'start':start,'end':end,'contains':contains,'forward':forward,'result':probe.run(start,end,contains,forward)})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-portrait-touch-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':record['original_unchanged']}))
