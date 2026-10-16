"""Full original Creep D2 destructor on supplied owned-object vectors.
Shadow/shooter/sound/laser/particle/missile destructors, heap deletion,
string destruction, tree erase, portal/tower cleanup, map unregister and
hex-displacement release are recording stubs. Heap-delete uses an ARM bx lr
executable-memory-only stub because direct hook PC redirection did not
return correctly from one original conditional call. Original D2 code bytes
and preserved executable file remain unchanged. Native ownership loops,
compaction, pointer clears, footprint mark and ground-class guard execute.
No child destructor semantics, live registry/map/threading/GPU/game runs.
"""
import sys,itertools,json
from collections import deque
sys.path.insert(0,'tools')
from native_creep_death_reference import *
class Destructor(Death):
 def __init__(self):
  self.trace=deque(maxlen=35);super().__init__();self.original_body=bytes(self.u.mem_read(0x79af4,0x430))
 def hook(self,u,a,size,data):
  self.trace.append({"pc":hex(a),"lr":hex(u.reg_read(UC_ARM_REG_LR)),"r0":hex(u.reg_read(UC_ARM_REG_R0)),"r1":hex(u.reg_read(UC_ARM_REG_R1))})
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  calls={0xfc7a0:'shadow',0x81eb8:'shooter',0x11f6fc:'sound',0xde11c:'laser',0x110f0c:'particle',0x80f90:'missile',0x9cec8:'portal-clean',0xe9a74:'tower-clean',0x10352c:'map-unregister',0x10b904:'hex-release'}
  if a in calls:
   self.events.append({'method':calls[a],'object_offset':r0-E,'arg1':r1-E if E<=r1<E+0x300000 else r1,'arg2':r2,'arg3':r3});self.ret();return
  if a==0x36c18c:
   self.freed.append(r0-E);return
  if a in [0x36c06c,0x776d0]:self.ret();return
  super().hook(u,a,size,data)
 def run_destructor(self,kind,missiles,sprites,particle_count,extras):
  self.setup_tail(3,None,[0]*particle_count,[]);u=self.u;self.events=[];self.freed=[]
  # Executable-memory-only ARM bx lr stub preserves a conditional BLX return.
  u.mem_write(0x36c18c,I(0xe12fff1e))
  u.mem_write(E+0x250,I(E+0x8000));u.mem_write(E+0x8004,I(kind));u.mem_write(E+0x1c,I(E+0x9000));u.mem_write(E+0x9074,I(E+0xa000))
  for offset,value in [(0x148,4),(0x14c,5),(0x138,6)]:u.mem_write(E+offset,I(value))
  for offset,start,flags in [(0x368,E+0x10000,missiles),(0x284,E+0x12000,sprites)]:
   u.mem_write(E+offset,struct.pack('<3I',start,start+4*len(flags),start+1024))
   for i,flag in enumerate(flags):u.mem_write(start+i*4,I(E+(0x20000 if offset==0x368 else 0x24000)+i*0x200 if flag else 0))
  for index,offset in enumerate([0x290,0x2fc,0x134,0x338,0x27c,0x340]):
   u.mem_write(E+offset,I(E+0x40000+index*0x100 if extras else 0))
   if extras:u.mem_write(E+0x40000+index*0x100,bytes(0x100))
  try:self.invoke(0x79af4,[E])
  except Exception:
   Path("builds/creep-death-r124-destructor-failure-trace.json").write_text(json.dumps(list(self.trace),indent=2));raise
  bits=lambda o:struct.unpack('<I',u.mem_read(E+o,4))[0]
  assert bytes(u.mem_read(0x79af4,0x430))==self.original_body
  return {'events':self.events,'freed_offsets':self.freed,'missile_vector_empty':bits(0x368)==bits(0x36c),'sprite_vector_empty':bits(0x284)==bits(0x288),'particle_count':bits(0x278),'child_pointers':[bits(o) for o in [0x2fc,0x134,0x338,0x27c,0x340]],'footprint_mark':u.mem_read(E+0x40018,1)[0] if extras else None}
def main():
 p=Destructor();cases=[]
 for kind,missiles,sprites,count,extras in itertools.product([0,1,2],[[],[True],[True,False,True]],[[],[True],[True,False,True]],[0,1,3],[False,True]):
  inp={'kind':kind,'missiles':missiles,'sprites':sprites,'particle_count':count,'extras':extras};out=p.run_destructor(**inp)
  assert out['missile_vector_empty'] and out['sprite_vector_empty'] and out['particle_count']==0 and out['child_pointers']==[0]*5
  assert len([e for e in out['events'] if e['method']=='missile'])==sum(missiles)
  assert len([e for e in out['events'] if e['method']=='map-unregister'])==(kind==1)
  cases.append({'input':inp,'output':out})
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-death-destructor-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'source_unchanged':data['original_unchanged'],'example':cases[-1]}))
if __name__=='__main__':main()
