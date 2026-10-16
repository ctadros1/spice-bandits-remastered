"""Read-only original death-tail research, disconnected from frozen R123.
Full DoOnDying and CSprite.Update/interpolation execute on supplied records;
SetState executes with hover stub. Particle counts/lists are supplied, not
particle simulation. map-tree successor, deletion and memmove are explicit
stubs. No full SetDie/constructor/destructor/render/audio/GPU/game executes.
"""
import sys,itertools
sys.path.insert(0,'tools')
from native_map_order_reference import *
class Death(OrderProbe):
 def hook(self,u,a,size,data):
  r0=u.reg_read(UC_ARM_REG_R0)
  if a==0x36c12c:self.ret(self.next_nodes[r0]);return
  if a==0x36c18c:self.deleted.append(r0);self.ret();return
  if a==0x7e870:self.ret();return
  if a==0x1216c4:self.updated.append(r0)
  if a==0x798ec:self.state_calls.append(u.reg_read(UC_ARM_REG_R1))
  super().hook(u,a,size,data)
 def setup_tail(self,state,emitter,counts,sprites):
  self.reset();self.next_nodes={};self.updated=[];self.deleted=[];self.state_calls=[]
  u=self.u;u.mem_write(E+0x170,bytes([state]))
  if emitter is not None:
   u.mem_write(E+0x2c8,I(E+0x4000));u.mem_write(E+0x4004,I(37));u.mem_write(E+0x40b8,struct.pack('<i',emitter))
  u.mem_write(E+0x278,I(len(counts)))
  if counts:u.mem_write(E+0x270,I(E+0x5000))
  for i,count in enumerate(counts):
   node=E+0x5000+i*0x40;particle=E+0x6000+i*0x200
   self.next_nodes[node]=node+0x40 if i<len(counts)-1 else E+0x268
   u.mem_write(node+0x14,I(particle));u.mem_write(particle+0xb8,struct.pack('<i',count))
  start=E+0x7000;u.mem_write(E+0x284,struct.pack('<3I',start,start+4*len(sprites),start+256))
  for i,age in enumerate(sprites):
   sprite=E+0x8000+i*0x100;u.mem_write(start+i*4,I(sprite));u.mem_write(sprite+4,F(100));u.mem_write(sprite+8,F(age))
  self.emitter=emitter
 def tail_state(self):
  u=self.u;start,end=struct.unpack('<2I',u.mem_read(E+0x284,8));pointers=struct.unpack('<'+'I'*((end-start)//4),u.mem_read(start,end-start)) if end>start else []
  return {'state':u.mem_read(E+0x170,1)[0],'emitter_rate':struct.unpack('<I',u.mem_read(E+0x4004,4))[0] if self.emitter is not None else None,'sprites':[{'index':(p-E-0x8000)//0x100,'age_bits':struct.unpack('<I',u.mem_read(p+8,4))[0]} for p in pointers],'updated':[(p-E-0x8000)//0x100 for p in self.updated],'deleted':[(p-E-0x8000)//0x100 for p in self.deleted],'state_calls':list(self.state_calls)}
 def advance(self,dt):
  self.updated=[];self.deleted=[];self.state_calls=[];self.invoke(0x7beb8,[E,BITS(dt)]);return self.tail_state()
def main():
 p=Death();cases=[]
 for state,emitter,counts,sprites,dt in itertools.product([0,2,3,7],[None,-1,0,1,2],[[],[0],[1],[0,0],[0,1]],[[],[-1],[0],[1],[30],[0,1,0]],[0,.001,1,30,60]):
  p.setup_tail(state,emitter,counts,sprites);cases.append({'input':dict(state=state,emitter=emitter,particle_counts=counts,sprite_lifetimes=sprites,dt=dt),'output':p.advance(dt)})
 sequences=[]
 for emitter,counts,sprites,deltas in [(None,[],[30],[30,0]),(None,[],[1],[.5,.5,0]),(1,[],[],[30,30]),(0,[1],[],[30,30]),(0,[0],[0,1,0],[1,0])]:
  p.setup_tail(3,emitter,counts,sprites);sequences.append({'input':dict(emitter=emitter,particle_counts=counts,sprite_lifetimes=sprites),'frames':[{'dt':dt,'output':p.advance(dt)} for dt in deltas]})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases,'sequences':sequences}
 Path('tests/fixtures/native-creep-death-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sequences':sequences,'source_unchanged':data['original_unchanged']}))
if __name__=='__main__':main()
