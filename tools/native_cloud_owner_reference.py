"""R195 full original CTower.UpdatePoisons manager traversal on supplied records.
Cloud/bubble Update/D1 are explicit ordered recording/status callbacks, not
executed cloud damage, particle physics, bubble flight or destructors. Supplied
reserved vectors, parent pointers and status schedules exercise pre-update
removal/compaction, cloud-before-bubble order and parent-pointer detach behavior.
Memmove/delete/exception helpers are host stubs. Original bodies/files unchanged.
"""
from pathlib import Path
import sys,json,struct,itertools,hashlib,argparse
sys.path.insert(0,'tools')
from native_poison_lifecycle_reference import *
T=E+0x70000
class Manager(Lifecycle):
 def __init__(self):
  super().__init__();self.cloud_ids={};self.bubble_ids={};self.action={};self.bodies[0xe75dc]=bytes(self.u.mem_read(0xe75dc,464))
 def label(self,p):
  if p in self.cloud_ids:return {'object':'cloud','id':self.cloud_ids[p]}
  if p in self.bubble_ids:return {'object':'bubble','id':self.bubble_ids[p]}
  raise AssertionError('unexpected object pointer '+hex(p))
 def hook(self,u,a,size,data):
  r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1)
  if a in [0xe1268,0xe21d0]:
   info=self.label(r0);kind=info['object'];index=info['id'];self.events.append({'kind':kind+'_update_stub','id':index,'dt_ms_bits':r1,'argument_b':u.reg_read(UC_ARM_REG_R2)})
   change=self.action.get(kind+'_updates',{}).get(str(index),{})
   if kind=='cloud':
    if 'active' in change:u.mem_write(r0+0x18,bytes([change['active']]))
    if change.get('clear_ready_parent'):
     parent=self.word(r0+0x30)
     if parent and not (u.mem_read(parent+0x44,1)[0]&1):u.mem_write(r0+0x30,I(0))
   else:
    if 'active' in change:u.mem_write(r0+0x44,bytes([change['active']]))
    if 'particles' in change:u.mem_write(r0+0x58,I(self.word(r0+0x54)+4*change['particles']))
   self.ret();return
  if a in [0xe105c,0xe1f54]:self.events.append({'kind':self.label(r0)['object']+'_destructor_stub','id':self.label(r0)['id']});self.ret();return
  if a==0x36c18c:self.events.append({'kind':'delete_stub',**self.label(r0)});self.ret();return
  super().hook(u,a,size,data)
 def state(self):
  def pointers(off):
   start,end=struct.unpack('<2I',self.u.mem_read(T+off,8));assert end>=start and end-start<=512
   return [self.word(p) for p in range(start,end,4)]
  clouds=[]
  for p in pointers(0x1f4):
   parent=self.word(p+0x30);clouds.append({'id':self.cloud_ids[p],'active':self.u.mem_read(p+0x18,1)[0],'parent':self.bubble_ids[parent] if parent else None})
  bubbles=[]
  for p in pointers(0x200):bubbles.append({'id':self.bubble_ids[p],'active':self.u.mem_read(p+0x44,1)[0],'particles':(self.word(p+0x58)-self.word(p+0x54))//4})
  return {'clouds':clouds,'bubbles':bubbles,'events':self.events.copy()}
 def sequence(self,clouds,bubbles,actions,dt=30,b=0):
  self.setup_clouds([], [{'pos':[100,150]} for _ in clouds]);u=self.u;self.events=[];self.cloud_ids={E+i*0x200:i for i in range(len(clouds))};self.bubble_ids={E+0x72000+i*0x100:i for i in range(len(bubbles))}
  bs=list(self.bubble_ids);cs=list(self.cloud_ids)
  u.mem_write(T,bytes(0x300))
  for offset,start,items in [(0x1f4,E+0x71000,cs),(0x200,E+0x71100,bs)]:
   u.mem_write(T+offset,struct.pack('<3I',start,start+len(items)*4,start+512))
   if items:u.mem_write(start,struct.pack('<'+'I'*len(items),*items))
  for p,c in zip(cs,clouds):u.mem_write(p+0x18,bytes([c['active']]));u.mem_write(p+0x30,I(bs[c['parent']] if c.get('parent') is not None else 0))
  for i,(p,r) in enumerate(zip(bs,bubbles)):
   u.mem_write(p,bytes(0x100));u.mem_write(p+0x44,bytes([r['active']]));start=E+0x74000+i*0x100;u.mem_write(p+0x54,struct.pack('<3I',start,start+4*r['particles'],start+256))
  before=self.state();frames=[]
  for action in actions:self.events=[];self.action=action;self.invoke(0xe75dc,[T,BITS(dt),b]);frames.append(self.state())
  return {'input':{'clouds':clouds,'bubbles':bubbles,'actions':actions,'dt_ms':dt,'argument_b':b},'before':before,'frames':frames}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);args=ap.parse_args();out=Path(args.output);assert not out.exists();p=Manager();rows=[]
 # Exhaustively supplied small vectors and bit-polarity/particle-count boundaries.
 for cloud_flags,bubble_flags,count,dt,b in itertools.product([[1],[0],[1,0,1],[0,0,1],[2,1,0]],[[1],[0],[2],[1,0],[0,1]],[0,1],[0,.001,30,100],[0,1]):
  cs=[{'active':flag,'parent':i%len(bubble_flags)} for i,flag in enumerate(cloud_flags)];bs=[{'active':flag,'particles':count} for flag in bubble_flags]
  rows.append(p.sequence(cs,bs,[{},{}],dt,b))
 # Supplied callbacks demonstrate changed flags/counts are removed next pass.
 for clear_ready,second in itertools.product([False,True],[0,1]):
  cs=[{'active':1,'parent':0},{'active':1,'parent':1},{'active':1,'parent':1}];bs=[{'active':1,'particles':1},{'active':1,'particles':0}]
  actions=[{'cloud_updates':{'0':{'active':0},'1':{'clear_ready_parent':clear_ready},'2':{'clear_ready_parent':clear_ready}},'bubble_updates':{'0':{'active':0,'particles':0},'1':{'active':second}}},{'cloud_updates':{'1':{'clear_ready_parent':clear_ready},'2':{'clear_ready_parent':clear_ready}}},{}]
  rows.append(p.sequence(cs,bs,actions))
 # Empty vectors and an inactive bubble detaching the first non-null cloud
 # parent, even when that pointer refers to another still-active bubble.
 rows.append(p.sequence([],[],[{},{}]))
 for flag in [0,1,2]:
  rows.append(p.sequence([{'active':flag,'parent':None}],[],[{},{}]))
  rows.append(p.sequence([],[{'active':flag,'particles':0}],[{},{}]))
 rows.append(p.sequence([{'active':1,'parent':1},{'active':1,'parent':1}],[{'active':0,'particles':0},{'active':1,'particles':0}],[{},{}]))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 body=p.bodies[0xe75dc];report={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_original_body_and_file_unchanged':True,'body_bytes':len(body),'body_sha256':hashlib.sha256(body).hexdigest(),'sequences':rows}
 out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'sequences':len(rows),'frames':sum(len(x['frames']) for x in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}))
if __name__=='__main__':main()
