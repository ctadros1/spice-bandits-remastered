"""Original room/map routing with preserved mine and portal vtable pointers.

Supplied object depth/class fields replace construction. Complete original
room/map sort/before/body routing executes; actual mine/portal draw-method
entry calls are recorded then stubbed. No GPU or body/owner lifetimes.
"""
import sys
sys.path.insert(0,'tools')
from native_render_pass_reference import *
class MagicRoute(RenderProbe):
 def hook(self,u,a,size,data):
  if a==0xd4f04:
   for i,actor in enumerate(self.actors):
    address=E+0x10000+i*0x400
    self.u.mem_write(address+0xc,struct.pack('<i',actor['top']));self.u.mem_write(address+0x14,F(actor['height']))
    if actor['kind'] in ['mine','portal']:self.u.mem_write(address,I(0x479ae8 if actor['kind']=='mine' else 0x479b28))
  if a in [0x9b328,0x9c77c,0x9c7b8]:
   address=u.reg_read(UC_ARM_REG_R0);self.calls.append({'method':{0x9b328:'mine-body',0x9c77c:'portal-before',0x9c7b8:'portal-body-empty'}[a],'label':(address-E-0x10000)//0x400});self.ret();return
  super().hook(u,a,size,data)
 def scene(self,actors):
  self.actors=actors
  return self.frame([2 if x['kind']=='air' else 1 for x in actors],{})
p=MagicRoute();cases=[]
for actors in [[{'kind':'mine','top':80,'height':34},{'kind':'ground','top':85,'height':38},{'kind':'portal','top':100,'height':82},{'kind':'air','top':0,'height':100}],[{'kind':'ground','top':115,'height':38},{'kind':'mine','top':60,'height':34},{'kind':'portal','top':10,'height':82},{'kind':'portal','top':150,'height':82}]]:
 for reverse in [False,True]:
  values=list(reversed(actors)) if reverse else actors
  cases.append({'actors':values,'reverse':reverse,'output':p.scene(values)})
Path('tests/fixtures/native-magic-route-reference.json').write_text(json.dumps({'cases':cases,'method':'Full original room/map routing/sorting with supplied records. Mine/portal use preserved original vtables; actual render-method entry calls recorded then stubbed. No GPU/bodyinternals/constructorlifetime.','source_sha256':EXPECTED_SHA},indent=2)+'\n')
print(json.dumps({'cases':len(cases),'sample':cases[0]}))
