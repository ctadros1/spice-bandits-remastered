"""R150 full original supplied owner birth/status/smoke/dying count chronology.
Original Creep.C2/factory/PS.C2/SetState, UseFreeze, Creep.Update and its
ProcessSpeed/ProcessLsd/ProcessFreeze/DoOnDying/UpdateParticles, plus actual
Particle.Update/Emit run. R149 selected authored header inputs; additional
time_scale1/texture-count1/zero velocity variation supplied. Other motion and
texture fields remain zero. Freeze counter held1000 then manually0 atframe21;
HP set30 at21/100 at40; raw state3 supplied at41 without SetDie/explosions.
Non-particle movement/fly/portal/grow/bubble/hover/resource/string/map/texture/
allocator/random0/vector0/trig callbacks are explicit stubs. No actual spawn,
room/manager/timer producer/SetDie/destructor/trajectory/GPU/game execution.
"""
import sys,json,struct,math
from pathlib import Path
sys.path.insert(0,'tools')
from native_creep_particle_constructor_reference import *
class StatusBirth(Constructor):
 def hook(self,u,a,size,data):
  if a==0x36c12c:self.ret(self.owned_next[u.reg_read(UC_ARM_REG_R0)]);return
  if a==0x111088:
   ptr=u.reg_read(UC_ARM_REG_R0);self.dispatch.append({'alias':next(alias for alias,node in self.slots.items() if self.word(node+0x14)==ptr),'rate':self.word(ptr+4),'delta_bits':u.reg_read(UC_ARM_REG_R1)});self.ret();return
  super().hook(u,a,size,data)
 def invoke(self,address,args):
  self.u.reg_write(UC_ARM_REG_SP,STACK-0x2000);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(reg,value)
  self.u.emu_start(address|1,END,count=2000000);assert self.u.reg_read(UC_ARM_REG_PC)==END
 def run_status(self,name,slow):
  ctor=self.sample(name);u=self.u;nodes=[node for alias,node in sorted(self.slots.items())];self.owned_next={node:(nodes[i+1] if i+1<len(nodes) else E+0x268) for i,node in enumerate(nodes)};u.mem_write(E+0x270,I(nodes[0]));u.mem_write(E+0x3000+0x14,I(1000));counter=E+0x70000;u.mem_write(counter,I(2));self.invoke(0x7bc1c,[E,counter]);rows=[]
  for count in [2,1,0,-1,-2]:
   u.mem_write(counter,struct.pack('<i',count));u.mem_write(E+0x230,F(slow));self.invoke(0x7a924,[E]);self.invoke(0x7bc3c,[E]);self.dispatch=[];self.invoke(0x7bce4,[E,BITS(30),0]);rows.append({'counter':count,'remaining':self.word(E+0x208),'freeze_pointer':self.word(E+0x20c),'dispatch':self.dispatch.copy()})
  return {'resource':name,'pending_slow':slow,'constructor':ctor,'frames':rows}
class FreezeEmission(StatusBirth):
 def hook(self,u,a,size,data):
  if a in [0x7bfa8,0x7ead0,0x7ee94,0x7f058,0xfd8a4]:self.ret(0);return
  if a==0x111088:return # Execute complete original particle Update.
  if a==0x111418:
   self.emits.append({'alias':next(alias for alias,node in self.slots.items() if self.word(node+0x14)==u.reg_read(UC_ARM_REG_R0)),'count':u.reg_read(UC_ARM_REG_R1),'clock_bits':self.word(u.reg_read(UC_ARM_REG_R0)+0xc0)});return
  if a==0x110ab4:self.point(u.reg_read(UC_ARM_REG_R0),(0,0));self.ret();return
  if a in [0x36c88c,0x36c43c]:
   value=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0];self.ret(BITS(math.sin(value) if a==0x36c88c else math.cos(value)));return
  if a==0x36cafc:
   r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1);self.ret(r0%r1 if r1 else 0);return
  super().hook(u,a,size,data)
 def born_chain(self,head):
  values=[];seen=set()
  while head:
   assert head not in seen;seen.add(head);values.append(self.word(head+0x20));head=self.word(head+0x38)
  return values
 def full(self,name,dt_ms=30):
  # R151 audit: this probe retains the original initialized heavy-disable byte.
  # Preserve the R150 fixture bytes; R148 explicitly supplies both values.
  heavy=struct.unpack('<I',self.u.mem_read(0x40a1e8,4))[0]
  assert heavy==0x47c580 and bytes(self.u.mem_read(heavy,1))==b'\x01'
  self.emits=[];ctor=self.sample(name);u=self.u;nodes=[node for alias,node in sorted(self.slots.items())];self.owned_next={node:(nodes[i+1] if i+1<len(nodes) else E+0x268) for i,node in enumerate(nodes)};u.mem_write(E+0x270,I(nodes[0]));u.mem_write(E+0x3000+0x14,I(1000))
  for node in nodes:
   p=self.word(node+0x14);u.mem_write(p+0x50,F(1));u.mem_write(p+0x7c,I(1));u.mem_write(p+0x48,F(0));child=self.word(p+0x100);u.mem_write(child-12,bytes(12))
  counter=E+0x70000;u.mem_write(counter,I(1000));self.invoke(0x7bc1c,[E,counter]);rows=[]
  for frame in range(2001):
   if frame:
    if frame==21:u.mem_write(counter,I(0));u.mem_write(E+0x140,F(30))
    if frame==40:u.mem_write(E+0x140,F(100))
    if frame==41:u.mem_write(E+0x170,b"\x03")
    u.mem_write(E+0x230,F(-1));self.invoke(0x7e8d0,[E,BITS(dt_ms),0])
   rows.append({'frame':frame,'state':u.mem_read(E+0x170,1)[0],'counter':self.word(counter),'roots':[{'alias':alias,'active':self.word(self.word(node+0x14)+0xb8),'clock_bits':self.word(self.word(node+0x14)+0xc0),'release_bits':self.word(self.word(node+0x14)+0xc4),'rate':self.word(self.word(node+0x14)+4),'first_release':u.mem_read(self.word(node+0x14)+0xd6,1)[0],'active_birth_bits':self.born_chain(self.word(self.word(node+0x14)+0xdc)),'pool_size':len(self.born_chain(self.word(self.word(node+0x14)+0xe0)))} for alias,node in self.slots.items()]})
   if rows[-1]['state']==2:break
  return {'resource':name,'dt_ms':dt_ms,'frames':rows,'emits':self.emits}
def main():
 p=FreezeEmission()
 addresses=[0x7bc1c,0x7e8d0,0x7a924,0x7bbc0,0x7bc3c,0x7beb8,0x7bce4,0x111088,0x111418]
 for a in addresses:p.bodies[a]=bytes(p.u.mem_read(a,next(r['size'] for r in p.catalog if r['address']==a)))
 cases=[]
 for n in range(1,11):
  for dt in [16.667,30,100]:
   r=p.full('creeps/creep'+str(n),dt)
   assert r['frames'][0]['state']==0 and all(s['active']==0 and s['clock_bits']==0 for s in r['frames'][0]['roots'])
   assert r['frames'][-1]['state']==2 and all(s['active']==0 for s in r['frames'][-1]['roots'])
   for row in r['frames']:
    for root in row['roots']:assert len(root['active_birth_bits'])==root['active']
   assert all(bytes(p.u.mem_read(a,len(b)))==b for a,b in p.bodies.items());cases.append(r)
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_executed_bodies_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'r149_header_scope':'selected authored constructor fields; additional time_scale1/texture-count1/velocity variation0 supplied; other byteszero, fixed explicit callbacks; no trajectory/texture/parser fidelity claim','cases':cases}
 Path('tests/fixtures/native-creep-owner-birth-tail-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'full_original_bodies':data['full_function_bytes'],'all_final_state2_zero_active':True,'zero_count_emissions_recorded':sum(sum(e['count']==0 for e in c['emits']) for c in cases),'nonzero_emissions':sum(sum(e['count']>0 for e in c['emits']) for c in cases),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
