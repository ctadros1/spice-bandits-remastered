"""Original complete decal constructor/admission/update/manager/render probes.
Map-array header and linked cell lists are supplied. Original CDecal ctor,
AddDecal distance/guard loops, CDecal.Update/interpolation, manager removal
and Render/RenderAll execute. Allocation/list insert/unhook/delete, GL/quad,
alpha-test and child destructor are explicit stubs. Heap-delete uses an ARM
bx lr stub in emulated library memory; preserved file/function bytes unchanged.
No complete map loader, live spatial registry, threads, GPU or game executes.
"""
from native_map_order_reference import *
import itertools
class Decal(OrderProbe):
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==0x36c1bc:
   p=self.heap;self.heap+=0x100;u.mem_write(p,bytes(0x100));self.allocations.append(p);self.ret(p);return
  if a==0x36c18c:self.deleted.append(r0);return
  if a==0x9d644:self.destroyed.append(r0);self.ret();return
  if a==0x36c08c:
   nxt,prev=struct.unpack('<2I',u.mem_read(r0,8));u.mem_write(prev,I(nxt));u.mem_write(nxt+4,I(prev));self.unhooked.append(r0);self.ret();return
  if a==0x9dcf0:
   node=self.heap;self.heap+=0x100;prev=struct.unpack('<I',u.mem_read(r1+4,4))[0];value=struct.unpack('<I',u.mem_read(r2,4))[0]
   u.mem_write(node,struct.pack('<3I',r1,prev,value));u.mem_write(prev,I(node));u.mem_write(r1+4,I(node));self.ret();return
  if a in [0x36ca5c,0x36ca7c,0x1151a0]:self.ret();return
  if a==0x36b2ac:self.rgba=regs=[r0,r1,r2,r3];self.ret();return
  if a==0x115b30:
   sp=u.reg_read(UC_ARM_REG_SP);self.draws.append({'point_bits':[r1,r2],'rotation_bits':r3,'scale_bits':list(struct.unpack('<2I',u.mem_read(sp,8))),'rgba_bits':self.rgba});self.ret();return
  super().hook(u,a,size,data)
 def clean(self):
  self.reset();self.heap=E+0x80000;self.allocations=[];self.deleted=[];self.destroyed=[];self.unhooked=[];self.draws=[];self.rgba=[]
  self.u.mem_write(0x36c18c,I(0xe12fff1e))
  start=E+0x70000;self.u.mem_write(0x47eca4,struct.pack('<3I',start,start,start+4096))
 def ctor(self,life,fade,fade_in=0,scale=1):
  self.clean();p=E+0x1000;self.point(E+0x3000,(123.25,234.5));sp=STACK-0x1000;self.u.mem_write(sp,struct.pack('<4f',scale,life,fade,fade_in));self.invoke(0x9d5bc,[p,0,E+0x3000,E+0x4000]);return p
 def fields(self,p):
  u=self.u;bits=lambda o:struct.unpack('<I',u.mem_read(p+o,4))[0]
  return {'clock_bits':bits(0x20),'alpha_bits':bits(0x24),'deleted':bool(u.mem_read(p+0xc,1)[0]),'fading':bool(u.mem_read(p+0xd,1)[0])}
 def clock_sequence(self,life,fade,fade_in,deltas):
  p=self.ctor(life,fade,fade_in);start=E+0x70000;self.u.mem_write(start,I(p));self.u.mem_write(0x47eca8,I(start+4));out=[]
  for dt in [None]+deltas:
   self.destroyed=[];self.deleted=[];self.draws=[]
   if dt is not None:self.invoke(0x9d9b0,[BITS(dt)])
   self.invoke(0x9d97c,[])
   s,e=struct.unpack('<2I',self.u.mem_read(0x47eca4,8));out.append({'dt_ms':dt,'fields':self.fields(p),'present':e>s,'destroyed':len(self.destroyed),'draws':self.draws})
  return out
 def header(self,width,height):
  self.clean();self.invoke(0x10ce60,[E,width,height]);return list(struct.unpack('<10i',self.u.mem_read(E,40)))
 def admission(self,width,height,point,existing,kind=1,array=True):
  self.clean();u=self.u;A=E+0x10000;cols=width//100;rows=height//100;row_storage=E+0x20000
  u.mem_write(A,struct.pack('<10i',width,height,cols,rows,100,5,30,30,20,3));u.mem_write(A+40,struct.pack('<3I',row_storage,row_storage+rows*12,row_storage+4096))
  heads=[]
  for y in range(rows):
   cells=E+0x22000+y*0x1000;u.mem_write(row_storage+y*12,struct.pack('<3I',cells,cells+4*cols,cells+1024))
   for x in range(cols):
    cell=E+0x30000+y*0x1000+x*0x100;u.mem_write(cells+4*x,I(cell));head=cell+12;u.mem_write(head,struct.pack('<2I',head,head));heads.append(head)
  query=(int(point[1]/100)*cols+int(point[0]/100)) if point[0]>=0 and point[1]>=0 and int(point[0]/100)<cols and int(point[1]/100)<rows else 0
  head=heads[query] if heads else 0
  # Supplied existing list is in traversal order, independently of its history.
  previous=head
  for i,p in enumerate(existing):
   node=E+0x50000+i*0x20;decal=E+0x60000+i*0x100;self.point(decal,p);u.mem_write(decal+12,b'\0');u.mem_write(previous,I(node));u.mem_write(node,struct.pack('<3I',head,previous,decal));u.mem_write(head+4,I(node));previous=node
  self.point(E+0x4000,point);sp=STACK-0x1000;u.mem_write(sp,struct.pack('<4f',1.6,4000,4000,0));self.invoke(0x9d760,[A if array else 0,kind,E+0x4000,E+0x4500])
  s,e=struct.unpack('<2I',u.mem_read(0x47eca4,8));created=(e-s)//4
  members=[];node=struct.unpack('<I',u.mem_read(head,4))[0] if head else 0
  while node and node!=head:
   decal=struct.unpack('<I',u.mem_read(node+8,4))[0];members.append((decal-E-0x60000)//0x100 if E+0x60000<=decal<E+0x70000 else 'new');node=struct.unpack('<I',u.mem_read(node,4))[0]
  return {'created':created,'members':members,'old_deleted':[bool(u.mem_read(E+0x60000+i*0x100+12,1)[0]) for i in range(len(existing))],'unhooked':len(self.unhooked)}
def main():
 p=Decal();headers=[]
 for w,h in itertools.product([0,99,100,250,1024],[0,99]):headers.append({'width':w,'height':h,'fields':p.header(w,h)})
 clocks=[]
 for life,fade,fade_in in [(4000,4000,0),(100,200,0),(100,200,50),(0,200,0),(100,0,0)]:
  for dt in [16.667,30,100,133.333,4000]:
   count=min(600,int((life+fade)/dt)+4);clocks.append({'life':life,'fade':fade,'fade_in':fade_in,'dt_ms':dt,'frames':p.clock_sequence(life,fade,fade_in,[dt]*count)})
 admissions=[]
 for width,point,count,distance,kind,array in itertools.product([200,250],[[-.001,0],[0,0],[99.999,99.999],[100,100],[199.999,199.999],[200,200],[249,249],[250,250]],[0,1,3,4,19,20],[0,29.999,30,30.001],[0,1],[False,True]):
  old=[[point[0]+distance,point[1]] for _ in range(count)];inp={'width':width,'height':width,'point':point,'existing':old,'kind':kind,'array':array};admissions.append({'input':inp,'output':p.admission(**inp)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'headers':headers,'clocks':clocks,'admissions':admissions};Path('tests/fixtures/native-decal-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'headers':len(headers),'clock_sequences':len(clocks),'clock_frames':sum(len(c['frames']) for c in clocks),'admissions':len(admissions),'source_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
