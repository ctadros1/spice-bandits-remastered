"""Full original Animator constructor and PlayAnimation on supplied groups.
Name matching is an exact-string stub; resource/group records and zeroed
storage are supplied. No original Init/loader/owner/GPU executes.
"""
from native_animator_render_reference import *
class Play(Animator):
 def hook(self,u,a,size,data):
  if a==0x10f0cc:return
  if a==0x122020:self.ret(int(self.string(u.reg_read(UC_ARM_REG_R0))==self.string(u.reg_read(UC_ARM_REG_R1))));return
  super().hook(u,a,size,data)
 def run(self,current,request,phase,reset,stopped):
  self.reset();actor=E+0x4c;self.invoke(0x10ef20,[actor]);self.calls=[]
  group=E+0x3000;vector=E+0x3100;self.u.mem_write(group,struct.pack('<2I',vector,vector+8));self.u.mem_write(vector,struct.pack('<2I',E+0x4000,E+0x4100))
  for index,name in enumerate(['A','B']):
   resource=E+0x4000+index*0x100;self.u.mem_write(resource,I(self.intern(name)));self.u.mem_write(resource+0x2c,F(index));self.u.mem_write(resource+0x30,F(1-index))
  self.u.mem_write(actor+0x68,I(group));self.u.mem_write(actor+0x28,I(E+0x4000 if current=='A' else 0));self.u.mem_write(actor+0x64,F(phase));self.u.mem_write(actor+0x44,I(int(phase)));self.u.mem_write(actor+0x48,bytes([stopped]));self.u.mem_write(actor+0x70,bytes([reset]));self.u.mem_write(actor+0x3c,I(33));self.u.mem_write(actor+0x40,I(44))
  self.invoke(0x10f0cc,[actor,self.intern(request)]);pointer=struct.unpack('<I',self.u.mem_read(actor+0x28,4))[0]
  return {'name':self.string(struct.unpack('<I',self.u.mem_read(pointer,4))[0]) if pointer else '', 'phase':struct.unpack('<f',self.u.mem_read(actor+0x64,4))[0],'frame':struct.unpack('<I',self.u.mem_read(actor+0x44,4))[0],'stopped':bool(self.u.mem_read(actor+0x48,1)[0]),'alpha_start':struct.unpack('<I',self.u.mem_read(actor+0x3c,4))[0],'alpha_now':struct.unpack('<I',self.u.mem_read(actor+0x40,4))[0],'alpha_from':struct.unpack('<f',self.u.mem_read(actor+0x58,4))[0],'alpha_to':struct.unpack('<f',self.u.mem_read(actor+0x5c,4))[0]}
def main():
 p=Play();cases=[]
 for current in ['', 'A']:
  for request in ['A','B','missing']:
   for phase in [0,1.75]:
    for reset in [False,True]:
     for stopped in [False,True]:
      source=dict(current=current,request=request,phase=phase,reset=reset,stopped=stopped);cases.append({'input':source,'output':p.run(**source)})
 x={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA};Path('tests/fixtures/native-animator-play-reference.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':x['original_unchanged']}))
if __name__=='__main__':main()
