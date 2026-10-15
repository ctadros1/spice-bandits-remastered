"""Record animation declarations from six original menu methods.

Original ARM code executes. Objective-C objects, arrays, numbers, layer methods,
frame getters/setters, animation lookup and CG transforms are explicit stubs;
no UIKit/Core Animation interpolation or original framebuffer executes.
"""
from native_creep_reference import *
import math

class AnimationProbe(Probe):
 def __init__(self):
  super().__init__()
  for index,(address,name) in enumerate([(0x40a07c,'easeInEaseOut'),(0x40a084,'linear'),(0x40a0c0,'easeIn')]):
   pointer=MEMORY+80000+index*4;self.u.mem_write(pointer,I(self.intern(name)));self.u.mem_write(address,I(pointer))
  self.ivars={}
  for s in json.load(open('original/analysis/decrypted-symbols.json')):
   if s['value'] and s['name'].startswith('_OBJC_IVAR_$_TowerViewController.'):
    self.ivars[s['name'].split('.')[-1]]=struct.unpack('<I',self.u.mem_read(s['value'],4))[0]
 def cf(self,a):
  try:return self.string(struct.unpack('<I',self.u.mem_read(a+8,4))[0])
  except (UcError,UnicodeDecodeError):return 'unknown-cf-'+hex(a)
 def alloc(self,value):
  a=E+0x10000+len(self.objects)*0x100;self.objects[a]=value;return a
 def value(self,a):return self.objects.get(a,a)
 def outlet(self,name):return self.outlets.get(name,E+0x6000)
 def hook(self,u,a,size,data):
  if a==0x36c7cc:
   self.ret(self.random.pop(0));return
  if a==0x36abdc:
   pointer=u.reg_read(UC_ARM_REG_R0);angle=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R1)))[0]
   u.mem_write(pointer,struct.pack('<6f',math.cos(angle),math.sin(angle),-math.sin(angle),math.cos(angle),0,0));self.ret(pointer);return
  if a==0x36be9c:
   pointer,receiver=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1)]
   index=(receiver-(E+0x7000))//0x100
   u.mem_write(pointer,struct.pack('<4f',*[10+index*20,15+index*10,16,16]));self.ret();return
  if a==0x36be6c:
   receiver,selector,r2,r3=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)];name=self.string(selector)
   if name=='animationWithKeyPath:':self.ret(self.alloc({'keypath':self.cf(r2)}));return
   if name=='numberWithFloat:':self.ret(self.alloc(struct.unpack('<f',I(r2))[0]));return
   if name=='arrayWithObjects:':
    args=[r2,r3]+list(struct.unpack('<16I',u.mem_read(u.reg_read(UC_ARM_REG_SP),64)));values=[]
    for arg in args:
     if not arg:break
     values.append(self.value(arg))
    self.ret(self.alloc(values));return
   if name=='imageNamed:':self.ret(self.alloc(self.cf(r2)));return
   if name in self.outlets:self.ret(self.outlet(name));return
   if name in ('layer','subviews'):self.ret(receiver);return
   if name=='objectAtIndex:':self.ret(E+0x7000+r2*0x100);return
   if name=='deviceType':self.ret(0);return
   if name=='animationForKey:':self.ret(1 if self.active_eye else 0);return
   if name=='functionWithName:':self.ret(self.alloc({'timing':self.string(r2)}));return
   if name=='addAnimation:forKey:':self.animations.append({'target':self.names_by_address.get(receiver,hex(receiver)),'name':self.cf(r3),'properties':self.value(r2).copy()});self.ret();return
   if name=='setAnchorPoint:':self.anchors[self.names_by_address.get(receiver,hex(receiver))]=[struct.unpack('<f',I(v))[0] for v in (r2,r3)]
   elif name=='setFrame:':self.frames.append(list(struct.unpack('<4f',I(r2)+I(r3)+u.mem_read(u.reg_read(UC_ARM_REG_SP),8))))
   elif name=='setDuration:' or name=='setAnimationDuration:':
    duration=struct.unpack('<d',I(r2)+I(r3))[0]
    if name=='setDuration:':self.objects[receiver]['duration']=duration
    else:self.rocket_durations[self.names_by_address.get(receiver,hex(receiver))]=duration
   elif name in ('setValues:','setKeyTimes:','setToValue:','setFromValue:','setTimingFunction:'):
    self.objects[receiver][name[3:-1]]=self.value(r2)
   elif name in ('setCumulative:','setAutoreverses:','setRemovedOnCompletion:'):
    self.objects[receiver][name[3:-1]]=bool(r2)
   elif name=='setRepeatCount:':self.objects[receiver]['RepeatCount']=str(struct.unpack('<f',I(r2))[0])
   elif name=='setOpacity:':self.hidden.append({'target':self.names_by_address.get(receiver,hex(receiver)),'opacity':struct.unpack('<f',I(r2))[0]})
   elif name=='startLogoLightAnimation:':self.light_targets.append(self.names_by_address.get(r2,hex(r2)))
   self.ret(E+0x6000);return
  super().hook(u,a,size,data)
 def prepare(self,random=(0,0),last=-1,active=False):
  self.objects={};self.animations=[];self.anchors={};self.frames=[];self.hidden=[];self.rocket_durations={};self.light_targets=[];self.random=list(random);self.active_eye=active
  self.u.mem_write(E,bytes(0x8000));self.outlets={n:E+0x3000+i*0x100 for i,n in enumerate(['chainView','logoFastRotateView','logoView','logoWiresView','logoTextLightView','logoLightView','logoWiresLightView','logoEyesView','logoRocket1','logoRocket2','chain2View','gear1ImageView','gear2ImageView','gear3ImageView','spinnerImageView','starsImageView','earthImageView','moonImageView'])}
  self.names_by_address={a:n for n,a in self.outlets.items()};self.names_by_address.update({E+0x7000+i*0x100:'eye'+str(i) for i in range(4)})
  for n,a in self.outlets.items():self.u.mem_write(E+self.ivars[n],I(a))
  if last>=0:self.u.mem_write(E+self.ivars['lastEyePos'],I(E+0x7000+last*0x100))
  self.u.reg_write(UC_ARM_REG_SP,STACK-128);self.u.reg_write(UC_ARM_REG_LR,END|1)
  self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,0);self.u.reg_write(UC_ARM_REG_R2,self.outlet('logoTextLightView'))
 def run(self,function,random=(0,0),last=-1,active=False):
  self.prepare(random,last,active)
  try:self.u.emu_start(function|1,END,count=100000)
  except UcError:
   print('probe failed',hex(self.u.reg_read(UC_ARM_REG_PC)));raise
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'animations':self.animations,'anchors':self.anchors,'frames':self.frames,'hidden':self.hidden,'rocket_durations':self.rocket_durations,'light_targets':self.light_targets}

def main():
 p=AnimationProbe();record={'method':__doc__,'original_sha256':EXPECTED_SHA,'logo':p.run(0x20868),'chain':p.run(0x215b4),'gears':p.run(0x21ee0),'sky':p.run(0x21900),'light':p.run(0x21330),'eyes':[{'random':r,'duration_random':d,'last':last,'record':p.run(0x20e20,(r,d),last)} for r in range(3) for d in range(3) for last in range(-1,3)],'active_eye':p.run(0x20e20,active=True),'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-menu-animation-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:record[k] for k in ('logo','light','active_eye','original_unchanged')}))

if __name__=="__main__":main()
