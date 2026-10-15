"""Bounded original creep reference with supplied records. GPU/whole game omitted; fixture method states the exact recording stubs and limits."""
import sys
sys.path.insert(0,'tools')
from native_creep_owner_reference import *
class Body(OwnerProbe):
 def hook(self,u,a,size,data):
  if a==0x36b2ac:
   self.rgba=[struct.unpack('<f',I(u.reg_read(r)))[0] for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]];self.calls.append({'method':'color','rgba':self.rgba});self.ret();return
  if a==0x11515c:self.calls.append({'method':'blend','src':u.reg_read(UC_ARM_REG_R0),'dst':u.reg_read(UC_ARM_REG_R1)});self.ret();return
  methods={0x10f3a0:'anim-update',0x10f54c:'anim-render',0x10f1c4:'anim-frame',0xfc7b8:'shadow',0x82430:'shooter-render',0x111880:'particle-render'}
  if a in methods:
   self.calls.append({'method':methods[a],'actor_offset':u.reg_read(UC_ARM_REG_R0)-E,'rgba':self.rgba});self.ret();return
  if a==0x10f064:self.ret(E+0x5550);return
  super().hook(u,a,size,data)
 def body(self,kind,state,light,flags,secondary=False,add=False,status=0,enabled=True):
  self.rgba=None
  self.route(kind,state,flags,False,False,False)
  self.calls=[];self.rgba=None
  self.u.mem_write(4703312,bytes([enabled]));self.u.mem_write(E+0x2bc,b'\x01');self.u.mem_write(E+0x34,F(light));self.u.mem_write(E+0x144,I(100));self.u.mem_write(E+0x140,F(100));self.u.mem_write(E+0x2fc,I(E+0x9000))
  self.u.mem_write(E+0x334,bytes([add]));self.u.mem_write(E+0x208,I(status))
  if secondary:self.u.mem_write(E+0x324,I(E+0x7000));self.u.mem_write(E+0xf4,F(.5))
  self.invoke(0x7f5c8,[E]);return list(self.calls)
def main():
 p=Body();cases=[]
 for kind in [1,2]:
  for state in [0,2,3]:
   for light in [.3,.7,1]:
    for flags in [[],[False],[True],[True,False]]:
     for secondary,add,status in [(False,False,0),(True,False,0),(False,True,0),(False,False,1)]:
      cases.append({'resource_type':kind,'state':state,'light':light,'missile_flags_a0':flags,'secondary':secondary,'add_flag334':add,'status208':status,'calls':p.body(kind,state,light,flags,secondary,add,status)})
 result={'method':'Full original CCreep.Render0x7f5c8 against supplied resource/state/brightness/owner missile and status fields. GL, animator, shadow, shooter, missile and GPU calls recording stubs; full health bar/particles-tree/render internals and whole game not executed.','source_sha256':EXPECTED_SHA,'cases':cases,'disabled_calls':p.body(1,0,1,[True],enabled=False),'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-creep-body-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'calls':sum(len(c['calls']) for c in cases),'original_unchanged':result['original_unchanged']}));print(json.dumps(cases[8]))

if __name__=="__main__":main()
