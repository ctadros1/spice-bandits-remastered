"""Original menu bubble path/group declarations with explicit graphics stubs.

ARM startBubble executes against supplied coordinates/speed/distance. Paths,
Objective-C animations/numbers/arrays/colors/layers are recorded stubs; no Core
Animation interpolation, UIKit conversion, original random stream or rasterizer.
"""
from native_menu_animation_reference import *

class BubbleProbe(AnimationProbe):
 def hook(self,u,a,size,data):
  if getattr(self,'callback_mode',False):
   if a==0x36cafc:self.ret(u.reg_read(UC_ARM_REG_R0)%u.reg_read(UC_ARM_REG_R1));return
   if a==0x36be6c:
    selector=u.reg_read(UC_ARM_REG_R1);arg=u.reg_read(UC_ARM_REG_R2);name=self.string(selector)
    if name=='createBubble':self.ordinary+=1;self.ret();return
    if name=='createBubble:':self.extra.append(arg);self.ret();return
    if name=='count':self.ret(9);return
  if getattr(self,'creating',False):
   if a==0x36cadc:self.ret(u.reg_read(UC_ARM_REG_R0)%u.reg_read(UC_ARM_REG_R1));return
   if a==0x36be9c:
    output,receiver,selector=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)]
    if self.string(selector)=='frame':u.mem_write(output,struct.pack('<4f',*self.source_frame))
    else:
     x=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R3)))[0];y=struct.unpack('<f',u.mem_read(u.reg_read(UC_ARM_REG_SP),4))[0]
     self.converted_inputs.append([x,y]);u.mem_write(output,struct.pack('<2f',x+self.conversion_offset[0],y+self.conversion_offset[1]))
    self.ret();return
   if a==0x36be6c:
    receiver,selector,arg=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)];name=self.string(selector)
    if name=='objectAtIndex:':self.ret(E+0x7000 if receiver==E+0x3000 else E+0x7800);return
    if name=='count':self.ret(150);return
    if name=='startBubble:X:Y:time:distance:side:':
     x=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R3)))[0]
     y,speed,distance,side=struct.unpack('<3fI',u.mem_read(u.reg_read(UC_ARM_REG_SP),16))
     self.creation.append({'x':x,'y':y,'speed':speed,'distance':distance,'side':side});self.ret();return
  if a==0x36b07c:self.ret(self.alloc({'points':[]}));return
  if a in (0x36b08c,0x36b06c):
   path,x,y=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R2,UC_ARM_REG_R3)]
   self.objects[path]['points'].append([struct.unpack('<f',I(x))[0],struct.unpack('<f',I(y))[0]]);self.ret();return
  if a==0x36b09c:self.ret();return
  if a==0x36be6c:
   receiver,selector,arg=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)];name=self.string(selector)
   if name=='animation':self.ret(self.alloc({'keypath':'group'}));return
   if name in ('setPath:','setAnimations:'):
    self.objects[receiver][name[3:-1]]=self.value(arg);self.ret();return
   if name=='colorWithRed:green:blue:alpha:':
    rgba=list(struct.unpack('<4f',I(arg)+I(u.reg_read(UC_ARM_REG_R3))+u.mem_read(u.reg_read(UC_ARM_REG_SP),8)))
    self.ret(self.alloc({'rgba':rgba}));return
   if name=='CGColor':self.ret(receiver);return
  super().hook(u,a,size,data)
 def bubble(self,x,y,speed,distance,side=0):
  self.callback_mode=False;self.creating=False;self.prepare();self.names_by_address[E+0x7000]="bubble-slot"
  self.u.reg_write(UC_ARM_REG_R2,E+0x7000);self.u.reg_write(UC_ARM_REG_R3,BITS(x))
  self.u.mem_write(STACK-128,F(y)+F(speed)+F(distance)+I(side))
  self.u.emu_start(0x1f901,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'x':x,'y':y,'speed':speed,'distance':distance,'side':side,'group':self.animations}

 def create(self,width,height,rx,ry,offset_y,slot):
  self.callback_mode=False;self.prepare((rx,ry));self.creating=True;self.source_frame=[10,20,width,height];self.conversion_offset=(0,offset_y);self.converted_inputs=[];self.creation=[]
  self.u.mem_write(E+self.ivars['bubblesView'],I(E+0x3000));self.u.mem_write(E+self.ivars['flotersView'],I(E+0x3100));self.u.mem_write(E+self.ivars['m_nIndex'],I(slot))
  self.u.reg_write(UC_ARM_REG_R2,0)
  self.u.emu_start(0x1f669,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'width':width,'height':height,'random_x':rx,'random_y':ry,'conversion_offset_y':offset_y,'slot':slot,'converted_inputs':self.converted_inputs,'bubble':self.creation,'next_slot':struct.unpack('<I',self.u.mem_read(E+self.ivars['m_nIndex'],4))[0]}

 def callback(self,chance,target,count):
  self.prepare((chance,target,count));self.callback_mode=True;self.creating=False;self.ordinary=0;self.extra=[]
  self.u.mem_write(E+self.ivars['flotersView'],I(E+0x3000));self.u.reg_write(UC_ARM_REG_R2,0)
  self.u.emu_start(0x1f39d,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'chance':chance,'target_random':target,'count_random':count,'source_count':9,'ordinary':self.ordinary,'extra':self.extra}

p=BubbleProbe();record={'method':__doc__,'original_sha256':EXPECTED_SHA,'timer_interval':struct.unpack('<d',p.u.mem_read(0x1efb8,8))[0],'cases':[p.bubble(x,y,speed,distance,side) for x,y in [(0,0),(20,30),(333.5,234.5)] for speed in [30,60,120] for distance in [0,25,100] for side in [0,1]],'creations':[p.create(w,h,rx,ry,offset,slot) for w,h in [(100,200),(130,71),(215,57)] for rx,ry in [(0,0),(25,75),(99,99)] for offset in [-200,0,128] for slot in [0,149]],'callbacks':[p.callback(chance,target,count) for chance in [0,9,10,49,60,110] for target in [0,8,99] for count in [0,19,99]],'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-menu-bubble-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(record['cases']),'sample':record['cases'][9],'original_unchanged':record['original_unchanged']}))
