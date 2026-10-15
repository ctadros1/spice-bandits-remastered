"""Original fly paths and music-note callbacks with explicit framework stubs.

Original ARM arithmetic executes. Fast enumeration, CGRect queries, music flag,
Objective-C animation objects and CGPath commands are controlled recording stubs.
No UIKit/Core Animation rendering or original random stream is executed.
"""
from native_menu_float_reference import *

class MotionProbe(FloatProbe):
 def hook(self,u,a,size,data):
  if a==0x25ef8:self.ret(E+0x6000);return
  if a==0x36b05c:
   path=u.reg_read(UC_ARM_REG_R0)
   values=list(struct.unpack('<6f',I(u.reg_read(UC_ARM_REG_R2))+I(u.reg_read(UC_ARM_REG_R3))+u.mem_read(u.reg_read(UC_ARM_REG_SP),16)))
   self.objects[path].setdefault('curves',[]).append(values);self.ret();return
  if a==0x36be9c:
   output,receiver,selector=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)]
   if self.string(selector)=='frame':u.mem_write(output,struct.pack('<4f',*self.frame));self.ret();return
  if a==0x36be6c:
   receiver,selector,arg,r3=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)];name=self.string(selector)
   if name=='deviceType':self.ret(self.device);return
   if name=='countByEnumeratingWithState:objects:count:':
    first=struct.unpack('<I',u.mem_read(arg,4))[0]==0
    if first:
     u.mem_write(arg,I(1)+I(r3)+I(E+0x6000));u.mem_write(r3,I(E+0x7000))
    self.ret(1 if first else 0);return
   if name=='setCenter:':self.centers.append(list(struct.unpack('<2f',I(arg)+I(r3))));self.ret();return
   if name=='setHidden:':self.hidden.append({'hidden':bool(arg)});self.ret();return
   if name=='startLogoEyeAnimation':self.eye_calls+=1;self.ret();return
   if name=='count':self.ret(10);return
   if name=='startNote:X:Y:time:distance:':
    x=struct.unpack('<f',I(r3))[0];y,duration,distance=struct.unpack('<3f',u.mem_read(u.reg_read(UC_ARM_REG_SP),12))
    self.spawns.append({'x':x,'y':y,'duration':duration,'distance':distance});self.ret();return
  super().hook(u,a,size,data)
 def setup(self,random,frame,device):
  self.prepare(random);self.frame=frame;self.device=device;self.centers=[];self.spawns=[];self.eye_calls=0
  self.names_by_address[E+0x7000]='motion-item'
  self.u.mem_write(E+self.ivars['logoFlies'],I(E+0x3000))
  self.u.mem_write(E+self.ivars['notesView'],I(E+0x3000))
 def execute(self,address):
  try:self.u.emu_start(address|1,END,count=100000)
  except UcError:print('motion failed',hex(self.u.reg_read(UC_ARM_REG_PC)));raise
  assert self.u.reg_read(UC_ARM_REG_PC)==END
 def flies(self,frame,random,device):
  self.setup(random,frame,device);self.execute(0x203e4)
  return {'frame':frame,'random':random,'device':device,'centers':self.centers,'animations':self.animations}
 def note(self,x,y,duration,distance,random,device):
  self.setup([random],[0,0,100,150],device)
  self.u.reg_write(UC_ARM_REG_R2,E+0x7000);self.u.reg_write(UC_ARM_REG_R3,BITS(x))
  self.u.mem_write(STACK-128,F(y)+F(duration)+F(distance));self.execute(0x1fc10)
  return {'x':x,'y':y,'duration':duration,'distance':distance,'random':random,'device':device,'hidden':self.hidden,'animations':self.animations}
 def notes_callback(self,width,height,rx,ry,index,music):
  self.setup([rx,ry],[10,20,width,height],0)
  self.u.mem_write(0x47be04,I(1 if music else 0));self.u.mem_write(E+self.ivars['m_nNotesIndex'],I(index))
  self.execute(0x1f470)
  return {'width':width,'height':height,'random_x':rx,'random_y':ry,'index':index,'music':music,'eye_calls':self.eye_calls,'spawns':self.spawns,'next_index':struct.unpack('<I',self.u.mem_read(E+self.ivars['m_nNotesIndex'],4))[0]}

def main():
 p=MotionProbe();record={'method':__doc__,'original_sha256':EXPECTED_SHA,
  'flies':[p.flies([0,0,w,h],r,device) for w,h in [(293,185),(100,200)] for r in [[0]*80,[99]*80,list(range(80))] for device in [0,1]],
  'notes':[p.note(x,y,duration,distance,r,device) for x,y in [(0,0),(50,140)] for duration in [2,4] for distance in [20,100] for r in [0,25,99] for device in [0,1]],
  'callbacks':[p.notes_callback(w,h,rx,ry,index,music) for w,h in [(100,150),(50,200)] for rx,ry in [(0,0),(25,75),(99,99)] for index in [0,9] for music in [False,True]],
  'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-menu-motion-reference.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'flies':record['flies'][0],'note':record['notes'][5],'callback':record['callbacks'][3],'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
