"""Original SwitchPage layout declarations with controlled framework objects.

Original ARM page-building instructions execute. C++ allocation/string/map and
texture/text constructors, localization/notifications, tower lookup, hex lookup
and camera delivery are explicit stubs. Anchor points are supplied test inputs;
neither original constructors, rendering nor UIKit application state executes.
"""
from native_creep_reference import *

class LayoutProbe(Probe):
 def cf(self,a):return self.string(struct.unpack('<I',self.u.mem_read(a+8,4))[0])
 def allocate(self,size):
  at=self.next;self.next+=(size+511)//512*512;self.u.mem_write(at,bytes(size));return at
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)]
  if a==0x36c1bc:self.ret(self.allocate(r0));return
  if a in (0x36c18c,0x36c06c,0x36ca7c,0xf0c04,0x9916c):self.ret();return
  if a==0x36c04c:self.cpp[r0]=self.string(r1);self.ret(r0);return
  if a==0xb90dc:
   key=self.cpp[r1]
   if key not in self.slots:self.slots[key]=self.allocate(4)
   self.ret(self.slots[key]);return
  if a==0x125cdc:
   dims=struct.unpack('<2I',u.mem_read(u.reg_read(UC_ARM_REG_SP),8))
   self.metadata[r0]={'kind':'image','path':self.string(r1),'size':list(dims),'flip_h':False,'flip_v':False};u.mem_write(r0+8,I(dims[0])+I(dims[1]));u.mem_write(r0+0x37,b'\x01');self.ret(r0);return
  if a==0x122178:
   bounds=struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_SP)+32,4))[0]
   self.metadata[r0]={'kind':'text','font':self.cpp[r1],'font_size':struct.unpack('<f',I(r2))[0],'bounds':list(struct.unpack('<2f',u.mem_read(bounds,8))) if bounds else None};u.mem_write(r0+0x5e,b'\x01');self.ret(r0);return
  if a==0x1224b4:self.metadata[r0]['text']=self.string(r1);self.ret();return
  if a in (0x1261f4,0x126260) and not getattr(self,'running_uv',False):self.metadata[r0]['flip_h' if a==0x1261f4 else 'flip_v']=not bool(r1);self.ret();return
  if a==0x1080c4:self.camera.append(list(struct.unpack('<2f',u.mem_read(r1,8))));self.ret();return
  if a==0xe9784:self.ret(E+0x7000);return
  if a==0x1066fc:self.ret(E+0x7800);return
  if a==0x36be6c:
   name=self.string(r1)
   if name=='deviceType':self.ret(self.device);return
   if name=='localizedStringForKey:value:table:':self.ret(self.intern(self.cf(r2)));return
   if name=='UTF8String':self.ret(r0);return
   if name=='showTutorial:mainController:text:position:showOnce:afterClose:':
    self.notifications.append({'name':name,'stack':list(struct.unpack('<4I',u.mem_read(u.reg_read(UC_ARM_REG_SP),16)))});self.ret();return
   self.ret(E+0x9000);return
  super().hook(u,a,size,data)
 def run(self,page,device):
  self.device=device;self.next=E+0x20000;self.cpp={};self.slots={};self.metadata={};self.camera=[];self.notifications=[]
  self.u.mem_write(E,bytes(0x100000));room=E+0x1000;map_ptr=E+0x5000
  self.u.mem_write(E,I(room));self.u.mem_write(room+0xc,I(map_ptr));self.u.mem_write(room+0x398,I(E+0x6000));self.u.mem_write(room+0x464,I(E+0x6400));self.u.mem_write(room+0x4a8,I(E+0x6800))
  self.point(E+0x6000+0x3c,(321,702));self.point(E+0x6400+0x98,(840,15));self.point(E+0x7000+0x70,(777,333));self.point(map_ptr+0x18c,(800,600))
  self.anchors={E+0x6000+0x3c:'dock',E+0x6400+0x98:'wallet',E+0x8200+100:'base',E+0x8600+0x58:'source'}
  for slot,vector,storage,obj,posoff,point in [(0x40a110,E+0x8000,E+0x8100,E+0x8200,100,(500,400)),(0x40a22c,E+0x8400,E+0x8500,E+0x8600,0x58,(100,200))]:
   self.u.mem_write(slot,I(vector));self.u.mem_write(vector,I(storage)+I(storage+4));self.u.mem_write(storage,I(obj));self.point(obj+posoff,point)
  self.u.mem_write(0x40a214,I(E+0x8800));self.u.mem_write(E+0x8800,b'\x01')
  self.u.reg_write(UC_ARM_REG_SP,STACK-128);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,page)
  try:self.u.emu_start(0xb31c9,END,count=200000)
  except (UcError,KeyError):print('layout failed',page,device,hex(self.u.reg_read(UC_ARM_REG_PC)));raise
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  records={}
  for name,slot in self.slots.items():
   gui=struct.unpack('<I',self.u.mem_read(slot,4))[0]
   if not gui:continue
   kind,image,text=struct.unpack('<3I',self.u.mem_read(gui,12));obj=image if kind else text
   meta=self.metadata[obj].copy();offset=0x38 if kind else 0x94
   anchor=struct.unpack('<I',self.u.mem_read(obj+offset,4))[0]
   meta['anchor']=self.anchors.get(anchor,hex(anchor)) if anchor else None
   meta['offset']=list(struct.unpack('<2f',self.u.mem_read(obj+(0x20 if kind else 0x54),8)))
   meta['absolute']=list(struct.unpack('<2f',self.u.mem_read(obj+(0x3c if kind else 0x98),8)))
   flags=0x35 if kind else 0x5c
   meta['world']=bool(self.u.mem_read(obj+flags,1)[0]);meta['below_objects']=bool(self.u.mem_read(obj+flags+1,1)[0]);meta['visible']=bool(self.u.mem_read(obj+flags+2,1)[0])
   records[name]=meta
  return {'page':page,'device':device,'objects':records,'camera_requests':self.camera}

 def uv(self,value,vertical):
  self.running_uv=True;self.u.mem_write(E,bytes(0x1000));self.u.mem_write(E+4,I(E+0x800));self.u.mem_write(E+8,I(64)+I(60));self.u.mem_write(E+44,I(7)+I(11));self.u.mem_write(E+0x810,I(512)+I(1024))
  self.u.reg_write(UC_ARM_REG_SP,STACK-128);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E)
  self.u.emu_start(0x1260f9,END,count=10000);before=list(struct.unpack('<4f',self.u.mem_read(E+0x44,16)))
  self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,value)
  self.u.emu_start(0x126261 if vertical else 0x1261f5,END,count=10000);assert self.u.reg_read(UC_ARM_REG_PC)==END
  after=list(struct.unpack('<4f',self.u.mem_read(E+0x44,16)));self.running_uv=False
  return {'argument':value,'vertical':vertical,'before':before,'after':after,'mirrored':after[2]>after[3] if vertical else after[0]>after[1]}

def main():
 p=LayoutProbe();record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':[p.run(page,device) for page in range(18) for device in [1,2]],'uv_cases':[p.uv(value,vertical) for value in [0,1] for vertical in [False,True]],'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-tutorial-layout-reference.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'pages':len(record['cases']),'tablet_page2':record['cases'][5],'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
