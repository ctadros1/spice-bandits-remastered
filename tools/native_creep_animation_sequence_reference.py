"""Full original creep/animator Render/Update/Play/Stop/SetFrame owner sequence.
Supplied12-frame17FPS animation/group/creep records and process-speed fields.
Direction/attack/freeze/room actions are explicit inputs; their complete callers,
constructor, clock producer, loader and GPU do not execute. GL/final frame and
unrelated owner callbacks are recording stubs. Separate fixtures test freeze
manager/countdown/expiry ordering; this trace binds actual frame arithmetic.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_animation_render_reference import *
STEPS=[dict(name='000',dt=0),dict(name='walk',dt=60),dict(name='turn',dt=0,direction='RunUp'),dict(name='slow',dt=30,slow=.5),dict(name='paused',dt=30,paused=True),dict(name='frozen',dt=30,held=True),dict(name='freeze-expiry',dt=30,held=True),dict(name='resume',dt=30),dict(name='attack',dt=30,attack=True),dict(name='attack-resume',dt=30,play=True),dict(name='loop',dt=1000),dict(name='secondary',dt=30,secondary=True)]
class Sequence(CreepClock):
 def hook(self,u,a,size,data):
  if a in [0x10f0cc,0x10f13c,0x10efe4]:return
  if a==0x122020:self.ret(int(self.string(u.reg_read(UC_ARM_REG_R0))==self.string(u.reg_read(UC_ARM_REG_R1))));return
  super().hook(u,a,size,data)
 def run(self):
  self.route(1,0,[],False,False,False);self.calls=[];self.updates=[];self.rgba=None;self.blend=[]
  for off,val in [(0x2bc,b'\x01'),(0x34,F(1)),(0x140,F(100)),(0x144,I(100)),(0x228,F(1)),(0x22c,F(1)),(0x1014,I(1000))]:self.u.mem_write(E+off,val)
  self.u.mem_write(4703312,b'\x01');group=E+0x5000;entries=E+0x6000;self.u.mem_write(group,struct.pack('<2I',entries,entries+8))
  for i,name in enumerate(['RunDown','RunUp']):
   animation=E+0x10000+i*0x1000;vec=animation+0x100;self.u.mem_write(animation,bytes(0x1000));self.u.mem_write(entries+i*4,I(animation));self.u.mem_write(animation,I(self.intern(name)));self.u.mem_write(animation+0xc,I(12));self.u.mem_write(animation+0x10,F(17));self.u.mem_write(animation+0x14,b'\x01');self.u.mem_write(animation+0x34,I(vec));self.u.mem_write(animation+0x38,I(vec+48))
   for k in range(12):self.u.mem_write(vec+k*4,I(animation+0x200+k*0x40))
  for actor in [E+0x4c,E+0xc0]:
   self.u.mem_write(actor+0x28,I(E+0x10000));self.u.mem_write(actor+0x2c,b'\x01');self.u.mem_write(actor+0x34,F(1));self.u.mem_write(actor+0x38,F(1));self.u.mem_write(actor+0x68,I(group));self.u.mem_write(actor+0x71,b'\x01')
  stop=struct.unpack('<I',self.u.mem_read(0x40a26c,4))[0];delta=struct.unpack('<I',self.u.mem_read(0x40a270,4))[0];rows=[];direction='RunDown'
  for step in STEPS:
   direction=step.get('direction',direction)
   if step.get('direction') or step.get('play'):self.invoke(0x10f0cc,[E+0x4c,self.intern(direction)])
   if step.get('attack'):
    for actor in [E+0x4c,E+0xc0]:self.invoke(0x10f13c,[actor]);self.invoke(0x10efe4,[actor,0])
   if step.get('secondary'):
    self.u.mem_write(E+0x324,I(E+0x7000));self.u.mem_write(E+0xf4,F(.6));self.u.mem_write(E+0xf8,F(.6));self.invoke(0x10f0cc,[E+0xc0,self.intern(direction)])
   self.u.mem_write(E+0x20c,I(E+0x9000 if step.get('held') else 0));self.u.mem_write(E+0x230,F(step.get('slow',-1)));self.invoke(0x7a924,[E]);self.u.mem_write(stop,bytes([bool(step.get('paused'))]));self.u.mem_write(delta,F(step['dt']));self.calls=[];self.updates=[];self.invoke(0x7f5c8,[E]);clocks=[]
   for actor in [E+0x4c,E+0xc0] if step.get('secondary') else [E+0x4c]:
    clocks.append({'phase_bits':struct.unpack('<I',self.u.mem_read(actor+0x64,4))[0],'frame':struct.unpack('<I',self.u.mem_read(actor+0x44,4))[0],'stopped':bool(self.u.mem_read(actor+0x48,1)[0]),'name':direction})
   rows.append({'input':step,'clocks':clocks,'updates':list(self.updates)})
  return rows
if __name__=='__main__':
 p=Sequence();rows=p.run();data={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'rows':rows};Path('tests/fixtures/native-creep-animation-sequence-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'rows':len(rows),'original_unchanged':data['original_unchanged'],'clocks':[r['clocks'] for r in rows]}))
