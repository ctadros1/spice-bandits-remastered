"""Original full SetDie + CSprite constructor with preserved resource inputs.
All creep1..10 params/texture names/particle alias order are supplied from
imported preserved definitions. Resource lookup/string/map operations,
particle factory/Emit, sound, decal submission, rand0 and random-vector(1,0)
are explicit recording stubs. Sprite constructor and float geometry execute.
No resource loader, actual particle creation/audio/decal render/GPU/game.
"""
import sys,itertools,json,math
from collections import deque
sys.path.insert(0,'tools')
from native_creep_death_setdie_reference import *
class Effects(SetDie):
 def __init__(self):
  self.trace=deque(maxlen=40);super().__init__()
 def hook(self,u,a,size,data):
  self.trace.append({"pc":hex(a),"r0":hex(u.reg_read(UC_ARM_REG_R0)),"r1":hex(u.reg_read(UC_ARM_REG_R1)),"lr":hex(u.reg_read(UC_ARM_REG_LR))})
  regs=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]];r0,r1,r2,r3=regs
  if a==0x36c11c:self.ret(self.next_nodes[r0]);return
  if a==0x11794c:
   key=self.string(r1);self.events.append({'method':'param','name':key});self.ret(self.parameters.get(key,0));return
  if a==0x1177e0:
   key=self.string(r1);self.events.append({'method':'texture','name':key});self.ret(self.textures.get(key,0));return
  if a==0x117940:self.ret(E+0x3000);return
  if a==0x36c7cc:self.ret(0);return
  if a in [0x36cafc,0x36cadc]:self.ret(r0%r1 if r1 else 0);return
  if a==0x36c9dc:
   source=self.string(r0);needle=self.string(r1);index=source.find(needle);self.ret(r0+index if index>=0 else 0);return
  if a==0x36c05c:u.mem_write(r0,bytes(u.mem_read(r1,4)));self.ret(r0);return
  if a==0x36c04c:u.mem_write(r0,I(r1));self.ret(r0);return
  if a==0x36c06c:self.ret();return
  if a==0x36c1bc:
   result=self.heap;self.heap+=max(0x100,((r0+0xff)//0x100)*0x100);u.mem_write(result,bytes(max(0x100,r0)));self.ret(result);return
  if a==0x110ab4:self.point(r0,(1,0));self.ret();return
  if a==0x120520:self.events.append({'method':'sound-load','cue':self.string(r0)});self.ret(E+0x60000);return
  if a==0x11f950:self.events.append({'method':'sound-play','point':list(struct.unpack('<2f',u.mem_read(r1,8)))});self.ret();return
  if a==0x11f6fc:self.ret();return
  if a==0x113d9c:
   name=self.string(r0);system=E+0x80000+len(self.particle_systems)*0x1000;u.mem_write(system,bytes(0x200));definition=self.systems[name]
   u.mem_write(system+4,I(int(definition['num_release'])));u.mem_write(system+8,F(float(definition['release_interval'])));self.particle_systems.append((name,system));self.ret(system);return
  if a==0x77294:
   alias=self.string(struct.unpack('<I',u.mem_read(r1,4))[0]);slot=E+0x70000+len(self.particle_slots)*4;self.particle_slots[alias]=slot;self.ret(slot);return
  if a==0x111418:
   self.events.append({'method':'emit','system':self.particle_systems[-1][0],'count':r1,'point':list(struct.unpack('<2f',u.mem_read(r0+0xa0,8))),'interval_bits':struct.unpack('<I',u.mem_read(r0+8,4))[0]});self.ret(1);return
  if a==0x9d760:
   sp=u.reg_read(UC_ARM_REG_SP);self.events.append({'method':'decal','kind':r1,'position':list(struct.unpack('<2f',u.mem_read(r2,8))),'texture':self.texture_names.get(r3),'stack_floats':list(struct.unpack('<4f',u.mem_read(sp,16)))});self.ret();return
  super().hook(u,a,size,data)
 def run_effects(self,name,kind,already,logical,offset,aim,animator):
  self.setup_tail(0,None,[],[]);u=self.u;self.events=[];self.heap=E+0x90000;self.particle_systems=[];self.particle_slots={};self.parameters={};self.textures={};self.texture_names={}
  resource=self.animations[name];u.mem_write(E+0x250,I(E+0x1000));u.mem_write(E+0x104c,I(E+0x2000));u.mem_write(E+0x320,bytes([already]));self.point(E+0x188,logical);self.point(E+0x54,offset);self.point(E+0x190,aim);self.point(E+0x4c,animator)
  u.mem_write(E+0x1c,I(E+0x4000));u.mem_write(E+0x426c,I(E+0x4500))
  for index,(key,value) in enumerate(resource['params'].items()):
   node=E+0x20000+index*0x100;self.parameters[key]=node
   if isinstance(value,list):
    if not all(isinstance(v,str) for v in value):continue
    vector=node+0x40;u.mem_write(node+0x1c,struct.pack('<2I',vector,vector+len(value)*4))
    for i,v in enumerate(value):u.mem_write(vector+i*4,I(self.intern(v)))
   elif isinstance(value,(int,float)):u.mem_write(node+0xc,F(value))
  for index,key in enumerate(resource['textures']):
   texture=E+0x50000+index*0x100;self.textures[key]=texture;self.texture_names[texture]=key
  bindings=self.bindings.get(name,{});end=E+0x3004
  u.mem_write(E+0x3014,I(len(bindings)));u.mem_write(E+0x300c,I(E+0x10000 if bindings else end))
  for index,(alias,binding) in enumerate(sorted(bindings.items())):
   node=E+0x10000+index*0x40;info=E+0x14000+index*0x40
   u.mem_write(node+0x10,struct.pack('<2I',self.intern(alias),info));u.mem_write(info,I(self.intern(str(binding['filename']))));self.next_nodes[node]=node+0x40 if index+1<len(bindings) else end
  self.point(E+0x6500,(64,0));u.mem_write(0x40a1ec,I(E+0x6500))
  vector=E+0x40000;u.mem_write(E+0x284,struct.pack('<3I',vector,vector,vector+1024))
  try:self.invoke(0x7a150,[E,kind])
  except Exception:
   Path("builds/creep-death-r124-effects-failure-trace.json").write_text(json.dumps(list(self.trace),indent=2));raise
  start,end=struct.unpack('<2I',u.mem_read(E+0x284,8));sprites=[]
  for addr in range(start,end,4):
   sprite=struct.unpack('<I',u.mem_read(addr,4))[0]
   sprites.append({'life_bits':struct.unpack('<I',u.mem_read(sprite+8,4))[0],'position':list(struct.unpack('<2f',u.mem_read(sprite+0x14,8))),'initial_scale':list(struct.unpack('<2f',u.mem_read(sprite+0x2c,8))),'scale_div_bits':struct.unpack('<I',u.mem_read(sprite+0x54,4))[0],'blend_mode':struct.unpack('<I',u.mem_read(sprite+0x58,4))[0],'relative_scale':u.mem_read(sprite+0x5c,1)[0],'texture':self.texture_names.get(struct.unpack('<I',u.mem_read(sprite,4))[0])})
  return {'state':u.mem_read(E+0x170,1)[0],'crater_created':u.mem_read(E+0x320,1)[0],'sprites':sprites,'events':self.events,'particle_systems':[{'name':name,'interval_bits':struct.unpack('<I',u.mem_read(system+8,4))[0]} for name,system in self.particle_systems]}
def main():
 p=Effects();p.animations=json.loads(Path('game/data/animations.json').read_text());particles=json.loads(Path('game/data/particles.json').read_text());p.bindings=particles['bindings'];p.systems=particles['systems'];cases=[]
 for name,kind,already in itertools.product(['creeps/creep'+str(i) for i in range(1,11)],range(5),[False,True]):
  inp={'name':name,'kind':kind,'already':already,'logical':[320.25,230.75],'offset':[3.5,-7.25],'aim':[333.25,219.75],'animator':[330.5,220.5]};out=p.run_effects(**inp);cases.append({'input':inp,'output':out})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-death-effects-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'source_unchanged':data['original_unchanged'],'first':cases[0]}))

if __name__=="__main__":main()
