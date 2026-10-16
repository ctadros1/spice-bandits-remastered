"""Original full Creep.Update with DoOnDying/UpdateParticles/Particle.Update.
Supplied frozen death owner, preserved death-system lifetime/count values
and explicitly linked already-born particles. Particle construction/emission,
trajectory/child effects/resource loader omitted. Non-tail creep subsystems
are recording no-op stubs; native Sprite.Update/interpolation execute.
No full SetDie/room/manager/constructor/renderer/GPU/game runs here.
"""
import sys,json
sys.path.insert(0,'tools')
from native_creep_death_reference import *
class TailClock(Death):
 def hook(self,u,a,size,data):
  if a in [0x7a924,0x7bc3c,0x7bbc0,0x7bfa8,0x7ead0,0x7ee94,0x7f058,0xfd8a4]:self.ret(0);return
  if a==0x111418:self.emits+=1;self.ret(1);return
  super().hook(u,a,size,data)
 def setup_clocks(self,names,dt):
  self.setup_tail(3,None,[int(self.definitions[n]['num_release']) for n in names],[300]);u=self.u;self.names=names;self.emits=0
  u.mem_write(E+0x140,F(0));u.mem_write(E+0x144,I(100));u.mem_write(E+0x2a8,F(10000));u.mem_write(E+0x2b8,I(E+0x2000));u.mem_write(E+0x2dc,b'\x01')
  for i,name in enumerate(names):
   d=self.definitions[name];s=E+0x6000+i*0x200;u.mem_write(s,bytes(0x200));u.mem_write(s,I(100));u.mem_write(s+4,I(int(d['num_release'])));u.mem_write(s+8,F(5));u.mem_write(s+12,F(float(d['life_cycle'])));u.mem_write(s+0x50,F(1));u.mem_write(s+0xfc,I(E+0x10000+i*0x100));count=int(d['num_release']);u.mem_write(s+0xb8,I(count));u.mem_write(s+0xdc,I(E+0x100000+i*0x10000))
   for j in range(count):
    particle=E+0x100000+i*0x10000+j*0x40;u.mem_write(particle,bytes(0x40));u.mem_write(particle+0x38,I(particle+0x40 if j+1<count else 0))
  u.mem_write(E+0x8004,F(300));u.mem_write(E+0x8054,F(5));u.mem_write(E+0x8058,I(1));u.mem_write(E+0x805c,b'\x01');u.mem_write(E+0x802c,struct.pack('<2f',.5,.5))
 def fields(self):
  u=self.u
  return {'state':u.mem_read(E+0x170,1)[0],'systems':[{'name':name,'active':struct.unpack('<I',u.mem_read(E+0x6000+i*0x200+0xb8,4))[0],'clock_bits':struct.unpack('<I',u.mem_read(E+0x6000+i*0x200+0xc0,4))[0]} for i,name in enumerate(self.names)],'sprites':len(self.tail_state()['sprites']),'emission_calls':self.emits}
def main():
 p=TailClock();particles=json.loads(Path('game/data/particles.json').read_text());p.definitions=particles['systems'];cases=[]
 for resource in ['creeps/creep'+str(i) for i in range(1,11)]:
  names=[b['filename'] for alias,b in sorted(particles['bindings'][resource].items()) if 'explosion' in alias]
  for dt in [16.667,30,33.333,100,133.333]:
   p.setup_clocks(names,dt);rows=[{'frame':0,'output':p.fields()}]
   for frame in range(1,150):
    p.invoke(0x7e8d0,[E,BITS(dt),0]);out=p.fields();rows.append({'frame':frame,'output':out})
    if out['state']==2:break
   assert rows[-1]['output']['state']==2 and p.emits==0
   cases.append({'resource':resource,'dt_ms':dt,'frames':rows})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-death-tail-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'source_unchanged':data['original_unchanged'],'examples':[(c['resource'],c['dt_ms'],c['frames'][-1]['frame']) for c in cases[:5]]}))

if __name__=="__main__":main()
