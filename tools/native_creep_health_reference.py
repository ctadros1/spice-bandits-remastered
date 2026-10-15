"""Full original creep Render with supplied health, animator and texture records.

The original conditional, float32 geometry, RGBA and foreground UV cropping
execute. Animator/shadow/body, GL and quad submission are recording stubs;
no original texture loader, GPU, growth/portal lifetime or whole game runs.
Texture dimensions match the preserved32x16 life-bar images; UVs are supplied
standalone and atlas examples rather than a claimed original GL allocation.
"""
from native_creep_body_reference import *


class Health(Body):
 def hook(self,u,a,size,data):
  if a in [0x1152d0,0x1156f4]:
   regs=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
   if a==0x1152d0:
    self.calls.append({'method':'health-background','point':list(struct.unpack('<2f',I(regs[1])+I(regs[2]))),'rgba':self.rgba})
   else:
    values=list(struct.unpack('<8f',I(regs[1])+I(regs[2])+I(regs[3])+u.mem_read(u.reg_read(UC_ARM_REG_SP),20)))
    self.calls.append({'method':'health-fill','texture_id':regs[0],'geometry_uv':values,'rgba':self.rgba})
   self.ret();return
  super().hook(u,a,size,data)
 def health(self,kind,state,hp,maximum,alpha,point,uv):
  self.body(kind,state,0.3,[])
  self.point(E+0x4c,point)
  self.u.mem_write(E+0x140,F(hp));self.u.mem_write(E+0x144,I(maximum));self.u.mem_write(E+0x2e0,F(alpha))
  self.u.mem_write(E+0x2c0,I(E+0x8000));self.u.mem_write(E+0x2c4,I(E+0x8100))
  self.u.mem_write(E+0x8104,I(E+0x8200));self.u.mem_write(E+0x8200,I(114))
  self.u.mem_write(E+0x8108,struct.pack('<2i',32,16));self.u.mem_write(E+0x8144,struct.pack('<4f',*uv))
  self.calls=[];self.rgba=None
  self.invoke(0x7f5c8,[E])
  return list(self.calls)


def main():
 p=Health();cases=[]
 for kind in [1,2]:
  for state in [0,2,3,4]:
   for hp,maximum in [(-10,100),(0,100),(.1,100),(33.333,100),(99.9,100),(100,100),(120,100),(0,0)]:
    for alpha in [0,.35,1]:
     for point,uv in [([0,0],[0,1,0,1]),([231.25,150.875],[.125,.625,.25,.75]),([-7.125,-100.75],[0,1,0,1])]:
      cases.append({'resource_type':kind,'state':state,'hp':hp,'max_hp':maximum,'alpha':alpha,'animator_point':point,'uv':uv,'calls':p.health(kind,state,hp,maximum,alpha,point,uv)})
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-creep-health-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'backgrounds':sum(any(x['method']=='health-background' for x in c['calls']) for c in cases),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
