"""Full original CCreep.Render, CAnimProcessor.Render/Update and ProcessSpeed.
Supplied two 8-frame records, creep/resource/status/global-delta fields.
Final quads, GL, shadows and unrelated owner callbacks are recording stubs.
No original constructor, movement/room-clock producer, GPU or whole app runs.
Repeated Render deliberately runs again; no source method call is skipped.
"""
import sys
sys.path.insert(0,'tools')
from native_animator_clock_reference import *
class CreepClock(Clock):
 def hook(self,u,a,size,data):
  if a==0x10f3a0:
   self.updates.append(u.reg_read(UC_ARM_REG_R0)-E);return
  super().hook(u,a,size,data)
 def sequence(self,kind,secondary,held,stopped,base,slow):
  self.route(kind,0,[],False,False,False);self.calls=[];self.updates=[];self.rgba=None;self.blend=[]
  self.u.mem_write(E+0x2bc,b'\x01');self.u.mem_write(4703312,b'\x01');self.u.mem_write(E+0x34,F(.7))
  self.u.mem_write(E+0x140,F(100));self.u.mem_write(E+0x144,I(100));self.u.mem_write(E+0x324,I(E+0x7000 if secondary else 0))
  self.u.mem_write(E+0x20c,I(held));self.u.mem_write(E+0x1014,I(base));self.u.mem_write(E+0x228,F(1));self.u.mem_write(E+0x22c,F(1))
  stop_ptr=struct.unpack('<I',self.u.mem_read(0x40a26c,4))[0];delta_ptr=struct.unpack('<I',self.u.mem_read(0x40a270,4))[0];self.u.mem_write(stop_ptr,bytes([stopped]))
  for i in range(2):
   actor=E+[0x4c,0xc0][i];anim=E+0x10000+i*0x1000;vec=anim+0x100
   self.u.mem_write(anim,bytes(0x1000));self.u.mem_write(actor+0x28,I(anim));self.u.mem_write(actor+0x2c,b'\x01');self.u.mem_write(actor+0x34,F(1 if i==0 else .5));self.u.mem_write(actor+0x38,F(.7 if i==0 else .35));self.u.mem_write(actor+0x44,I(0));self.u.mem_write(actor+0x64,F(.75));self.u.mem_write(actor+0x71,b'\x01')
   self.u.mem_write(anim+0xc,I(8));self.u.mem_write(anim+0x10,F(4));self.u.mem_write(anim+0x14,b'\x01');self.u.mem_write(anim+0x34,I(vec));self.u.mem_write(anim+0x38,I(vec+32))
   for k in range(8):self.u.mem_write(vec+k*4,I(anim+0x200+k*0x40))
  bits=lambda off:struct.unpack('<I',self.u.mem_read(E+off,4))[0]
  rows=[]
  for dt,draws in [(0,1),(30,1),(100,2),(200,1),(400,1),(3000,1),(30,1)]:
   self.u.mem_write(E+0x230,F(slow));self.invoke(0x7a924,[E]);self.u.mem_write(delta_ptr,F(dt));self.calls=[];self.updates=[]
   for draw in range(draws):self.invoke(0x7f5c8,[E])
   rows.append({'dt':dt,'draws':draws,'updates':list(self.updates),'frame_calls':[c for c in self.calls if c['method']=='frame'],'primary_phase_bits':bits(0xb0),'secondary_phase_bits':bits(0x124),'primary_frame':bits(0x90),'secondary_frame':bits(0x104),'primary_render_auto':self.u.mem_read(E+0xbd,1)[0],'secondary_render_auto':self.u.mem_read(E+0x131,1)[0]})
  return rows
def main():
 p=CreepClock();cases=[]
 for kind in [1,2]:
  for secondary in [False,True]:
   for held in [0,1]:
    for stopped in [False,True]:
     for base in [500,1000,3000]:
      for slow in [-1,.6]:
       inp=dict(kind=kind,secondary=secondary,held=held,stopped=stopped,base=base,slow=slow);cases.append({'input':inp,'frames':p.sequence(**inp)})
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-animation-render-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
 for c in cases:
  if c['input']==dict(kind=1,secondary=True,held=0,stopped=False,base=1000,slow=-1):print(c)
if __name__=='__main__':main()
