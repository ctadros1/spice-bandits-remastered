"""Full original creep Render plus non-interpolating Animator.Render.
Supplied creep/animation records; animator Update, RenderFrame, particles,
shadow and GPU are recording stubs. Status predicates and color/blend order
execute original ARMv7 bytes. No original scene, lifecycle or GPU executes.
"""
from native_creep_body_reference import *

class Status(Body):
 def hook(self,u,a,size,data):
  if a==0x10f54c:return # Run the complete original animator renderer.
  if a==0x11515c:self.blend=[u.reg_read(UC_ARM_REG_R0),u.reg_read(UC_ARM_REG_R1)]
  if a==0x10f1c4:
   self.calls.append({'method':'frame','actor_offset':u.reg_read(UC_ARM_REG_R0)-E,'rgba':self.rgba,'blend':list(self.blend)})
   self.ret();return
  super().hook(u,a,size,data)
 def render(self,kind,state,light,freeze,slow,alpha,secondary):
  self.route(kind,state,[],False,False,False);self.calls=[];self.rgba=None;self.blend=[]
  for offset,value in [(0x34,light),(0x230,slow)]:self.u.mem_write(E+offset,F(value))
  self.u.mem_write(E+0x208,I(freeze));self.u.mem_write(E+0x2bc,b'\x01');self.u.mem_write(4703312,b'\x01')
  for index,actor in enumerate([E+0x4c,E+0xc0]):
   animation=E+0x10000+index*0x100;frames=animation+0x80
   self.u.mem_write(actor+0x28,I(animation));self.u.mem_write(actor+0x2c,b'\x01');self.u.mem_write(actor+0x34,F(alpha if index==0 else secondary));self.u.mem_write(actor+0x38,F(light*(alpha if index==0 else secondary)));self.u.mem_write(actor+0x44,I(0))
   self.u.mem_write(animation+0xc,I(1));self.u.mem_write(animation+0x34,I(frames));self.u.mem_write(animation+0x38,I(frames+4));self.u.mem_write(frames,I(E+0x5550))
  self.u.mem_write(E+0x324,I(E+0x7000 if secondary>0 else 0))
  self.invoke(0x7f5c8,[E]);return self.calls

def main():
 p=Status();cases=[]
 for kind in [1,2]:
  for state in [0,2,3]:
   for light in [.0,.3,.7,1]:
    for freeze,slow in [(0,-1),(1,-1),(0,0),(0,.5),(0,1),(1,.5)]:
     for alpha,secondary in [(1,0),(.5,0),(0,0),(.4,.6)]:
      inp=dict(resource_type=kind,state=state,light=light,freeze=freeze,slow=slow,alpha=alpha,secondary=secondary)
      cases.append({'input':inp,'calls':p.render(kind,state,light,freeze,slow,alpha,secondary)})
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-creep-status-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(sum(c['method']=='frame' for c in case['calls']) for case in cases),'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
