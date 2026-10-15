"""Bounded original EAGLViewController menuTopView:loadMenu: dispatch.

Objective-C sends return explicit fixture identities/current menu/device type.
UIKit, layer rendering, callbacks, sessions, controller construction, sound
playback and asynchronous scheduling are stubs. Record original transition
requests and tab sound; this is not a UIKit animation or whole-game oracle.
"""
from native_creep_reference import *

class MenuProbe(Probe):
 def __init__(self):
  super().__init__()
  for index,(address,name) in enumerate([(0x40a088,'fade'),(0x40a08c,'fromLeft'),(0x40a090,'fromRight'),(0x40a098,'push')]):
   pointer=MEMORY+80000+index*4;self.u.mem_write(pointer,I(self.intern(name)));self.u.mem_write(address,I(pointer))
 def hook(self,u,a,size,data):
  if a==0x36be6c:
   receiver,sel,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
   name=self.string(sel)
   if name=='currentUserMenu':self.ret(self.old);return
   if name=='isCrystalUIActive':self.ret(0);return
   if name=='deviceType':self.ret(2);return
   if name=='setDuration:':self.result['duration']=struct.unpack('<d',I(r2)+I(r3))[0]
   elif name=='setType:':self.result['type']=self.string(r2)
   elif name=='setSubtype:':self.result['subtype']=self.string(r2)
   elif name=='addAnimation:forKey:':self.result['animation']=True
   elif name=='setCurrentUserMenu:':self.result['current']=r2
   elif name=='performSelector:withObject:afterDelay:':
    sp=u.reg_read(UC_ARM_REG_SP);self.result['scheduled'].append({'selector':self.string(r2),'delay':struct.unpack('<d',u.mem_read(sp,8))[0]})
   elif name=='setUserInteractionEnabled:':self.result['interaction']=bool(r2)
   self.ret(E+0x1000);return
  if a==0x36be9c:
   self.u.mem_write(u.reg_read(UC_ARM_REG_R0),struct.pack('<4f',0,0,1024,768));self.ret();return
  if a==0x1206e4:
   self.result['sounds'].append({'cue':self.string(u.reg_read(UC_ARM_REG_R0)),'layer':u.reg_read(UC_ARM_REG_R1)});self.ret();return
  super().hook(u,a,size,data)
 def run(self,old,new):
  self.old=old;self.result={'animation':False,'duration':0,'type':'','subtype':'','current':old,'sounds':[],'scheduled':[],'interaction':True}
  self.u.mem_write(E,bytes(0x3000));self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,0,E+0x1000,new]):self.u.reg_write(r,v)
  self.u.emu_start(0x36cd9,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
  return self.result

probe=MenuProbe();cases=[]
for old in [0,100,101,102,103,104,105,200]:
 for new in [100,101,102,103,104,105,200]:cases.append({'old':old,'new':new,'result':probe.run(old,new)})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-menu-navigation-reference.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'original_unchanged':record['original_unchanged']}))
