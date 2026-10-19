"""R190 bounded original poison particle methods and cloud apply callers.

Full EmitPoisonParticles60/StopPoisonParticles32, CPoison.DoDamage396,
DoSlowDown260, EraseCreepInRange60, EraseAllCreepsInRange48, reserved
vector push40 and CCreep.DoSlowDown32 execute unchanged. Actor/resource,
global ordered vector, circle positions, counters and root pointers are
supplied. Creep.DoDamage is an ordered recording stub (optional raw state3
write); ldexpf and memmove are explicit host stubs. No constructor/resource
loader, full cloud Update/expiry, real damage/death/reward, particle physics,
room schedule, GPU/audio or whole game executes. No original file is written.
"""
from pathlib import Path
import sys,json,struct,itertools,math,hashlib,argparse
sys.path.insert(0,'tools')
from native_creep_reference import *
BODY_ADDRS=[0x7bc88,0x7bcc4,0xe17c0,0xe16bc,0xe1a8c,0xe11ac,0xe1afc,0x7a904]
class PoisonProbe(Probe):
 def __init__(self):
  self.events=[];self.actors=[];self.kill_label=None
  super().__init__();rows=json.loads(Path('original/analysis/functions.json').read_text())
  self.bodies={a:bytes(self.u.mem_read(a,next(r['size'] for r in rows if r['address']==a))) for a in BODY_ADDRS}
 def word(self,a):return struct.unpack('<I',self.u.mem_read(a,4))[0]
 def hook(self,u,a,size,data):
  r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1)
  if a==0x36c62c:
   exponent=struct.unpack('<i',I(r1))[0];value=struct.unpack('<f',I(r0))[0]
   self.ret(BITS(math.ldexp(value,exponent)));return
  if a==0x36c6bc:
   length=u.reg_read(UC_ARM_REG_R2)
   if length:u.mem_write(r0,bytes(u.mem_read(r1,length)))
   self.ret(r0);return
  if a in [0x7bc88,0x7bcc4]:
   self.events.append({'kind':'emit' if a==0x7bc88 else 'stop','actor':self.actors.index(r0) if r0 in self.actors else 0,'type':r1})
  if a==0x7a62c:
   label=self.actors.index(r0);self.events.append({'kind':'damage_stub','actor':label,'owner':r1,'damage_bits':u.reg_read(UC_ARM_REG_R2),'argument_b':u.reg_read(UC_ARM_REG_R3),'damage_type':self.word(u.reg_read(UC_ARM_REG_SP))})
   if self.kill_label==label:u.mem_write(r0+0x170,b'\x03')
   self.ret();return
  super().hook(u,a,size,data)
 def invoke(self,address,args):
  self.u.reg_write(UC_ARM_REG_SP,STACK-0x1000);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(r,v&0xffffffff)
  self.u.emu_start(address|1,END,count=200000)
  assert self.u.reg_read(UC_ARM_REG_PC)==END,hex(self.u.reg_read(UC_ARM_REG_PC))
  assert all(bytes(self.u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
 def direct(self,method,tag,mask,flag,state,initial):
  u=self.u;u.mem_write(E,bytes(0x1000));u.mem_write(E+0x4000,bytes(0x600));self.actors=[E];self.events=[]
  u.mem_write(E+0x170,bytes([state]));u.mem_write(E+0x235,bytes([flag]))
  for i,off in enumerate([0x2cc,0x2d0,0x2d8]):
   p=E+0x4000+i*0x200;u.mem_write(E+off,I(p if mask&(1<<i) else 0));u.mem_write(p+4,struct.pack('<i',initial+i));u.mem_write(p+0xb0,I(9+i))
  before=bytes(u.mem_read(E,0x4600));self.invoke(0x7bc88 if method=='emit' else 0x7bcc4,[E,tag]);after=bytes(u.mem_read(E,0x4600));changed=[i for i,(a,b) in enumerate(zip(before,after)) if a!=b]
  assert all(any(root+4<=i<root+8 for root in [0x4000,0x4200,0x4400]) for i in changed)
  return {'input':dict(method=method,tag=tag,presence=mask,flag=flag,state=state,initial=initial),'rates':[struct.unpack('<i',u.mem_read(E+0x4004+i*0x200,4))[0] for i in range(3)],'changed_byte_offsets':changed}
 def setup_clouds(self,actors,clouds,kill_label=None):
  u=self.u;u.mem_write(E,bytes(0x80000));self.actors=[E+0x10000+i*0x1000 for i in range(len(actors))];self.events=[];self.kill_label=kill_label
  self.clouds=[E+i*0x200 for i in range(len(clouds))]
  vector=E+0x2000;data=E+0x3000;dimension=E+0x4000
  u.mem_write(0x40a11c,I(vector));u.mem_write(0x40a1ec,I(dimension));u.mem_write(dimension,F(32))
  u.mem_write(vector,struct.pack('<3I',data,data+4*len(actors),data+256))
  if actors:u.mem_write(data,struct.pack('<'+'I'*len(actors),*self.actors))
  for i,(a,p) in enumerate(zip(actors,self.actors)):
   u.mem_write(p+0x170,bytes([a.get('state',0)]));u.mem_write(p+0x235,bytes([a.get('flag',0)]));u.mem_write(p+0x138,I(a.get('id',100+i)));self.point(p+0x188,a['pos'])
   resource=E+0x60000+i*0x100;u.mem_write(resource+4,I(a.get('resource_kind',1)));u.mem_write(p+0x250,I(resource))
   for off,k in [(0x218,'poison_count'),(0x21c,'slow_count')]:u.mem_write(p+off,I(a.get(k,0)))
   u.mem_write(p+0x230,F(a.get('pending',-1)))
   for j,off in enumerate([0x2cc,0x2d0,0x2d8]):
    root=E+0x40000+i*0x1000+j*0x200;u.mem_write(p+off,I(root if a.get('presence',7)&(1<<j) else 0));u.mem_write(root+4,I(a.get('initial_rate',7)+j));u.mem_write(root+0xb0,I(9+j))
  for i,(c,p) in enumerate(zip(clouds,self.clouds)):
   d=E+0x8000+i*0x200;u.mem_write(p,I(d));self.point(p+8,c['pos']);u.mem_write(p+0x20,F(c.get('bonus',2.5)));u.mem_write(p+0x24,I(c.get('owner',43)));u.mem_write(p+0x28,bytes([c.get('radiation',0)]))
   for off,val in [(0x54,c.get('damage',10)),(0x58,c.get('range',2)),(0x6c,c.get('slowdown',50))]:u.mem_write(d+off,F(val))
   start=E+0xa000+i*0x200;ids=c.get('tracked',[]);u.mem_write(p+0x48,struct.pack('<3I',start,start+4*len(ids),start+256))
   if ids:u.mem_write(start,struct.pack('<'+'I'*len(ids),*[self.actors[j] for j in ids]))
 def snapshot(self):
  rows=[]
  for p in self.actors:
   rows.append({'state':self.u.mem_read(p+0x170,1)[0],'poison_count':self.word(p+0x218),'slow_count':self.word(p+0x21c),'pending_bits':self.word(p+0x230),'rates':[self.word(E+0x40000+self.actors.index(p)*0x1000+j*0x200+4) for j in range(3)]})
  tracked=[]
  for p in self.clouds:
   start,end=struct.unpack('<2I',self.u.mem_read(p+0x48,8));assert end>=start and end-start<=256
   tracked.append([self.actors.index(self.word(a)) for a in range(start,end,4)])
  return {'actors':rows,'tracked':tracked,'events':self.events.copy()}
 def cloud_sequence(self,actors,clouds,actions,kill_label=None):
  self.setup_clouds(actors,clouds,kill_label);states=[]
  for action in actions:
   self.events=[];address=self.clouds[action.get('cloud',0)]
   if action['kind']=='move':self.point(self.actors[action['actor']]+0x188,action['pos'])
   elif action['kind']=='state':self.u.mem_write(self.actors[action['actor']]+0x170,bytes([action['state']]))
   elif action['kind']=='clear':self.invoke(0xe11ac,[address])
   else:self.invoke(0xe17c0 if action['kind']=='damage' else 0xe16bc,[address,BITS(action.get('dt_ms',30)),action.get('argument_b',0)])
   states.append(self.snapshot())
  return {'input':{'actors':actors,'clouds':clouds,'actions':actions,'damage_stub_sets_state3_for':kill_label},'frames':states}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);args=ap.parse_args();out=Path(args.output);assert not out.exists()
 p=PoisonProbe();direct=[]
 for method,tag,mask,flag,state,initial in itertools.product(['emit','stop'],[-1,0,1,2,3,4],range(8),[0,1,2,3],[0,2,3,7],[-2,0,7]):direct.append(p.direct(method,tag,mask,flag,state,initial))
 sequences=[]
 actors=[{'pos':[100,150]},{'pos':[164,150]},{'pos':[100,150],'resource_kind':2},{'pos':[100,150],'state':3},{'pos':[110,150],'id':100},{'pos':[100,150],'state':2},{'pos':[100,150],'resource_kind':0}]
 for radiation,b,dt in itertools.product([0,1],[0,1],[0,16.667,30,100]):
  sequences.append(p.cloud_sequence(actors,[{'pos':[100,150],'radiation':radiation}], [{'kind':'damage','dt_ms':dt,'argument_b':b},{'kind':'damage','dt_ms':dt,'argument_b':b},{'kind':'move','actor':0,'pos':[500,500]},{'kind':'damage','dt_ms':dt,'argument_b':b},{'kind':'clear'}]))
 for order in [[0,1],[1,0]]:
  for second_rad in [0,1]:
   clouds=[{'pos':[100,150],'radiation':0},{'pos':[400,450],'radiation':second_rad}]
   sequences.append(p.cloud_sequence([{'pos':[100,150]}],clouds,[{'kind':'damage','cloud':i} for i in order]))
 for flag,pending,slow_count,slowdown in itertools.product([0,1,2,3],[-1,.5],[0,1,3],[-50,0,50,60,70]):
  sequences.append(p.cloud_sequence([{'pos':[100,150],'flag':flag,'pending':pending,'slow_count':slow_count}],[{'pos':[100,150],'slowdown':slowdown}],[{'kind':'slow'},{'kind':'slow'}]))
 for order in [[{'kind':'slow','cloud':0},{'kind':'damage','cloud':1}],[{'kind':'damage','cloud':1},{'kind':'slow','cloud':0}]]:
  sequences.append(p.cloud_sequence([{'pos':[100,150],'initial_rate':0}],[{'pos':[100,150],'slowdown':50},{'pos':[100,150],'radiation':0}],order))
 sequences.append(p.cloud_sequence([{'pos':[100,150]}],[{'pos':[100,150]}],[{'kind':'damage'},{'kind':'damage'}],kill_label=0))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 report={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_executed_bodies_unchanged':True,'bodies':{hex(a):{'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for a,b in p.bodies.items()},'direct':direct,'sequences':sequences}
 out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'direct_cases':len(direct),'sequences':len(sequences),'frames':sum(len(x['frames']) for x in sequences),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'bytes':out.stat().st_size,'original_unchanged':True}))
if __name__=='__main__':main()
