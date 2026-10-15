"""Original TutorialView show/remove animation requests and block callbacks.

Explicit tablet/controller identities and frame bounds; all Objective-C sends,
NIB/font/layout/session/notification/framework operations are recorded stubs.
The original show/remove/block instructions execute. UIKit pacing, rendering,
touch delivery, afterClose navigation and asynchronous execution do not.
"""
from native_creep_reference import *

class PortraitProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0x36be6c:
   receiver,selector,arg=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]];name=self.string(selector)
   if name=='deviceType':self.ret(2);return
   if name=='frameY':self.ret(BITS(438));return
   if name=='setAlpha:':self.result['alphas'].append(struct.unpack('<f',I(arg))[0])
   elif name=='animateWithDuration:delay:options:animations:completion:':
    sp=u.reg_read(UC_ARM_REG_SP);anim=struct.unpack('<I',u.mem_read(sp+12,4))[0];complete=struct.unpack('<I',u.mem_read(sp+16,4))[0]
    self.result['request']={'duration':struct.unpack('<d',I(arg)+I(u.reg_read(UC_ARM_REG_R3)))[0], 'delay':struct.unpack('<d',u.mem_read(sp,8))[0], 'options':struct.unpack('<I',u.mem_read(sp+8,4))[0]}
    self.blocks=[bytes(u.mem_read(anim,24)),bytes(u.mem_read(complete,24))]
   elif name in ['afterClose','removeFromSuperview']:self.result['callbacks'].append(name)
   elif name=='postNotificationName:object:userInfo:':
    string=struct.unpack('<I',u.mem_read(arg+8,4))[0];self.result['notifications'].append(self.string(string))
   self.ret(E+0x1000);return
  if a==0x36be9c:
   self.u.mem_write(u.reg_read(UC_ARM_REG_R0),struct.pack('<4f',0,0,1024,768));self.ret();return
  super().hook(u,a,size,data)
 def call(self,address,registers,stack=b''):
  self.u.reg_write(UC_ARM_REG_SP,STACK-0x1000);self.u.reg_write(UC_ARM_REG_LR,END|1)
  self.u.mem_write(STACK-0x1000,stack+bytes(64))
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],registers):self.u.reg_write(r,v)
  self.u.emu_start(address|1,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
 def run(self,kind,position,can_dismiss,pass_touches,finished):
  self.u.mem_write(E,bytes(0x4000));self.result={'alphas':[],'callbacks':[],'notifications':[]};self.blocks=[]
  self.call(0x650dc,[E,0,kind,E+0x2000],I(self.intern('Explicit custom message'))+I(position)+I(can_dismiss)+I(pass_touches))
  show={'initial_alphas':self.result['alphas'][:],'request':self.result['request'].copy()}
  block=MEMORY+90000;self.u.mem_write(block,self.blocks[0]);address=struct.unpack('<I',self.blocks[0][12:16])[0];self.call(address,[block,1,0,0]);show['target_alpha']=self.result['alphas'][-1]
  self.result={'alphas':[],'callbacks':[],'notifications':[]};self.call(0x66d3c,[E+0x1000,0,0,0]);remove={'request':self.result['request'].copy(),'notifications':self.result['notifications'][:]}
  self.u.mem_write(block,self.blocks[0]);address=struct.unpack('<I',self.blocks[0][12:16])[0];self.call(address,[block,1,0,0]);remove['target_alpha']=self.result['alphas'][-1]
  self.u.mem_write(block,self.blocks[1]);address=struct.unpack('<I',self.blocks[1][12:16])[0];self.call(address,[block,int(finished),0,0]);remove['callbacks']=self.result['callbacks'][:]
  return {'show':show,'remove':remove}

probe=PortraitProbe();cases=[]
for kind in [0,2,5,7,24]:
 for position in [0,4]:
  for dismiss,pass_touches in [(0,0),(1,0),(1,1)]:
   for finished in [False,True]:cases.append({'kind':kind,'position':position,'can_dismiss':dismiss,'pass_touches':pass_touches,'finished':finished,'result':probe.run(kind,position,dismiss,pass_touches,finished)})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-portrait-fade-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sample':cases[0]['result'],'original_unchanged':record['original_unchanged']}))
