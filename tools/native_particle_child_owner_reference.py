"""Bounded original particle-child allocation/reuse/update/destruction trace.

Supplied short-life records; resource/new/delete/string/unwind callbacks are
explicit stubs. This does not run original resource parsing, rendering or a room.
"""
from pathlib import Path
import sys,json,hashlib,struct
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_reference import *

class ChildProbe(Probe):
 def __init__(self):
  super().__init__();self.allocations=[];self.children=[];self.factories=[];self.updates=[];self.deletes=[]
  self.u.mem_write(0x36c18c,I(0xe12fff1e)) # External heap-delete stub only; ARM bx lr.
  self.protected={address:bytes(self.u.mem_read(address,size)) for address,size in [(0x111418,1052),(0x111088,912),(0x11184c,52),(0x110f1c,356)]}
  self.empty=E+0x5000;self.named=E+0x5100
  for address,name in [(self.empty,''),(self.named,'Creep1DebrisSmoke')]:
   self.u.mem_write(address-12,I(len(name))+I(len(name))+I(0));self.u.mem_write(address,name.encode()+b'\0')
  self.initialize(E,3,2,5.0,.3,self.named,(101.25,203.5))
 def initialize(self,address,maximum,number,interval,life,name,point):
  u=self.u;u.mem_write(address,bytes(0x200))
  for off,value in [(0,maximum),(4,number),(0xb0,number),(0x100,name)]:u.mem_write(address+off,I(value))
  for off,value in [(8,interval),(12,life),(0x10,1),(0x20,10),(0x24,-70),(0x38,1),(0x3c,1),(0x40,1),(0x44,1),(0x50,1),(0xa0,point[0]),(0xa4,point[1])]:u.mem_write(address+off,F(value))
  u.mem_write(address+0x7c,I(1));u.mem_write(address+0xd6,bytes([1]))
 def hook(self,u,address,size,data):
  r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1)
  if address==0x36c1bc:
   assert r0==0x40,('unexpected allocation',r0)
   ptr=E+0x6000+len(self.allocations)*0x100;u.mem_write(ptr,bytes(0x100));self.allocations.append(ptr);self.ret(ptr)
  elif address==0x113d9c:
   assert self.string(r0)=='Creep1DebrisSmoke'
   child=E+0x2000+len(self.children)*0x200
   self.initialize(child,10,1,.05,.12,self.empty,(0,0));self.children.append(child);self.factories.append({'name':self.string(r0),'info':r1,'child':child});self.ret(child)
  elif address==0x111088 and r0 in self.children:
   owner=[p for p in self.chain(self.word(E+0xdc)) if p['child']==r0]
   assert len(owner)==1 and owner[0]['position_bits']==[self.word(r0+0xa0),self.word(r0+0xa4)]
   self.updates.append({'child':r0,'dt_bits':r1,'position_bits':[self.word(r0+0xa0),self.word(r0+0xa4)],'clock_before_bits':self.word(r0+0xc0)})
  elif address==0x36c18c:self.deletes.append(r0) # Let executable-memory bx lr return.
  elif address in [0x36c06c,0x36ca5c,0x36ca7c]:self.ret()
  else:super().hook(u,address,size,data)
 def word(self,address):return struct.unpack('<I',self.u.mem_read(address,4))[0]
 def call(self,address,r0=E,r1=0,r2=0):
  u=self.u;self.stop=END;u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,value in [(UC_ARM_REG_R0,r0),(UC_ARM_REG_R1,r1),(UC_ARM_REG_R2,r2),(UC_ARM_REG_R3,0)]:u.reg_write(reg,value)
  try:u.emu_start(address|1,END,count=200000)
  except UcError as error:raise RuntimeError(str(error)+" PC="+hex(u.reg_read(UC_ARM_REG_PC))+" LR="+hex(u.reg_read(UC_ARM_REG_LR))) from error
  assert u.reg_read(UC_ARM_REG_PC)==END,('instruction limit',hex(u.reg_read(UC_ARM_REG_PC)))
 def chain(self,head):
  rows=[];seen=set()
  while head:
   assert head not in seen;seen.add(head)
   rows.append({'pointer':head,'child':self.word(head+0x3c),'born_bits':self.word(head+0x20),'position_bits':[self.word(head),self.word(head+4)]});head=self.word(head+0x38)
  return rows
 def state(self,label):
  return {'label':label,'parent_clock_bits':self.word(E+0xc0),'parent_active':self.word(E+0xb8),'active':self.chain(self.word(E+0xdc)),'pool':self.chain(self.word(E+0xe0)),'factory_calls':len(self.factories),'heap_allocations':len(self.allocations),'child_updates':len(self.updates),'children':[{'pointer':c,'clock_bits':self.word(c+0xc0),'active':self.word(c+0xb8),'active_chain':self.chain(self.word(c+0xdc)),'pool_chain':self.chain(self.word(c+0xe0))} for c in self.children]}

def main():
 p=ChildProbe();rows=[];p.call(0x111418,r1=2);rows.append(p.state('initial_emit'))
 assert len(p.factories)==2 and rows[-1]['parent_active']==2
 assert all(c['active']==0 and c['clock_bits']==0 for c in rows[-1]['children'])
 for frame in range(1,13):p.call(0x111088,r1=BITS(.03));rows.append(p.state('update_'+str(frame)))
 pooled=rows[-1];assert pooled['parent_active']==0 and len(pooled['pool'])==2 and not pooled['active']
 clock_before={c['pointer']:c['clock_bits'] for c in pooled['children']};updates_before=len(p.updates)
 p.call(0x111088,r1=BITS(.1));rows.append(p.state('pooled_wait'))
 assert len(p.updates)==updates_before and {c['pointer']:c['clock_bits'] for c in rows[-1]['children']}==clock_before
 p.call(0x111418,r1=1);rows.append(p.state('reuse'))
 assert len(p.factories)==2 and rows[-1]['parent_active']==1
 assert {c['pointer']:c['clock_bits'] for c in rows[-1]['children']}==clock_before
 reused=rows[-1]['active'][0];assert reused['child'] in p.children
 p.call(0x111088,r1=BITS(.03));rows.append(p.state('reused_update'))
 assert len(p.updates)==updates_before+1
 p.call(0x11184c);rows.append(p.state('restart'))
 assert rows[-1]['parent_active']==0 and len(rows[-1]['pool'])==2
 p.call(0x110f1c);rows.append(p.state('destructor'))
 assert not rows[-1]['active'] and not rows[-1]['pool']
 assert all(not c['active_chain'] and not c['pool_chain'] for c in rows[-1]['children'])
 assert set(p.children+p.allocations)==set(p.deletes) and len(p.deletes)==len(set(p.deletes))
 assert all(bytes(p.u.mem_read(address,len(code)))==code for address,code in p.protected.items())
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 report={'original_sha256':EXPECTED_SHA,'original_unchanged':True,'protected_original_functions_unchanged':True,'inputs':{'parent_life':.3,'child_life':.12,'parent_maximum':3,'initial_parent_emit':2,'child_maximum':10,'child_emit':1,'child_interval':.05,'dt':.03,'pooled_wait_dt':.1,'source_point':[101.25,203.5],'velocity':[10,-70],'wind_enabled':False,'variances':0,'child_name':'Creep1DebrisSmoke','factory_initialization':'explicit supplied short-life records, not authored resource parsing'},'states':rows,'factory':p.factories,'child_updates':p.updates,'deleted':p.deletes,'passed':True,'scope':'Full original parent Emit/Update/Restart/D2 and recursive child Update/Emit/D2 on supplied simple records. Factory records name and supplies child initialized fields; new/delete/string/unwind are explicit recording stubs, randomness disabled by supplied zero variances. External heap-delete ARM bx-lr stub modifies emulated stub only. Demonstrates child allocation-on-new-parent, frozen pooled child clocks, reuse without factory/reset, restart pooling and recursive destruction of active/pooled child particles. No original resource parser/factory initialization, trajectories/global RNG/whole room/render/GPU or game integration.'}
 Path('tests/fixtures/native-particle-child-owner-reference.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':True,'states':len(rows),'factory_calls':len(p.factories),'child_updates':len(p.updates),'heap_allocations':len(p.allocations),'deletes':len(p.deletes),'original_unchanged':True}))

if __name__=="__main__":main()
