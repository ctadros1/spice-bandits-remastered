"""R168 joined original owner/movement/hover plus full primary RenderFrame.
Uses the R167 supplied records and explicit subsystem/route/sinf stubs.
Full original CAnimProcessor.RenderFrame132 executes on the retained primary
animator after each original owner update. A supplied valid texture/frame,
frame offset and two scale pairs exercise the actual offset composition.
Final RenderFrameQuad is a recording stub; no quad/GPU submission, whole
Creep.Render/secondary/shadow/status/death/render clock or original loader.
"""
from native_creep_hover_owner_reference import *
class RenderOwner(Owner):
 def __init__(self):
  super().__init__();self.render_frames=[];self.draw_calls=[];self.geometry=None;self.bodies[0x10f1c4]=bytes(self.u.mem_read(0x10f1c4,132))
 def hook(self,u,a,size,data):
  if a==0x116440:
   self.draw_calls.append({'x_bits':u.reg_read(UC_ARM_REG_R1),'y_bits':u.reg_read(UC_ARM_REG_R2),'scale_bits':list(struct.unpack('<2I',u.mem_read(u.reg_read(UC_ARM_REG_R3),8)))})
   self.ret();return
  super().hook(u,a,size,data)
 def invoke(self,address,args):
  super().invoke(address,args)
  if address!=0x7e8d0:return
  u=self.u;actor=E+0x4c;animation=E+0x5000;frame=E+0x6000;texture=E+0x7000
  self.point(actor+0x10,self.geometry['scale']);self.point(actor+0x18,self.geometry['offset_scale']);u.mem_write(actor+0x28,I(animation));u.mem_write(animation+0x15,b'\0');u.mem_write(frame+0x10,I(texture));u.mem_write(texture+0x18,b'\x01');self.point(frame+0x18,self.geometry['frame_offset']);self.draw_calls=[]
  super().invoke(0x10f1c4,[actor,frame]);assert len(self.draw_calls)==1
  self.render_frames.append({'actor_position_bits':list(struct.unpack('<2I',u.mem_read(actor,8))),'actor_offset_bits':list(struct.unpack('<2I',u.mem_read(actor+8,8))),'quad_request':self.draw_calls[0]})
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=RenderOwner();cases=[]
 for flags,held,delta,scale,offset in itertools.product([(0,0),(1,1)],[False,True],[16.667,30,100],[(1,1),(.7,1.2)],[(0,0),(2.25,-3.5)]):
  p.geometry={'scale':scale,'offset_scale':scale,'frame_offset':offset};p.render_frames=[];frames=p.run(*flags,1000,held,delta)
  assert len(frames)==len(p.render_frames)
  for frame,render in zip(frames,p.render_frames):frame['render']=render
  cases.append({'input':{'hover348':flags[0],'hover349':flags[1],'freeze':held,'delta':delta,**p.geometry},'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA and all(bytes(p.u.mem_read(a,len(b)))==b for a,b in p.bodies.items())
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_or_slice_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'cases':cases};path=Path(args.output);path.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
