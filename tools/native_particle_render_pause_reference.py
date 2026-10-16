"""Full original particle Render wrapper with preallocated valid buffers and GL stubs."""
from native_particle_child_render_reference import *
class FullRender(RenderProbe):
 def hook(self,u,a,size,data):
  gl={0x36b63c:'vertex-pointer',0x36b3dc:'enable-client',0x11515c:'blend',0x36b3cc:'enable',0x36b1ac:'active-texture',0x36b2cc:'color-pointer',0x36b2ac:'color',0x36b5cc:'uv-pointer',0x36b3bc:'draw-arrays',0x11520c:'bind',0x36b3ac:'disable-client'}
  if a in gl:
   self.gl.append({'name':gl[a],'registers':[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]});self.ret();return
  super().hook(u,a,size,data)
 def full(self,stop,root_alpha,child_alpha,homogeneous,opacity,pose):
  expected=self.sample(child_alpha,homogeneous,opacity,pose);u=self.u;root=E;child=E+0x2000;parent=E+0x1000;tex=E+0x4000
  for address,r in zip([E+0x3000,E+0x3100],expected['input']['particles'][0]['child']['particles']):
   for off,v in zip([0x10,0x14,0x18,0x1c],r['rgba']):u.mem_write(address+off,F(v))
  # Match maximum-count cache and provide capacity for3parents*3treeparticles.
  u.mem_write(root,I(3));u.mem_write(root+0xcc,I(3));u.mem_write(root+0xb8,I(1));u.mem_write(child,I(2));u.mem_write(child+0xb8,I(2));u.mem_write(root+0xf8,I(54));u.mem_write(root+0xdc,I(parent));u.mem_write(root+0xec,I(E+0x9000));u.mem_write(root+0xe4,I(tex));u.mem_write(root+0x54,bytes([root_alpha]));u.mem_write(tex+4,I(E+0x5000));u.mem_write(E+0x5000,I(77));u.mem_write(E+0x5018,b'\1')
  stop_addr=self.word(0x40a26c);u.mem_write(stop_addr,bytes([stop]));protected={a:bytes(u.mem_read(a,n)) for a,n in [(0x111880,0x318),(0x111c64,1040),(0x112074,156),(0x112110,212)]};outputs=[]
  for held in range(2):
   self.gl=[];self.events=[];u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,root);u.emu_start(0x111881,END,count=200000);assert u.reg_read(UC_ARM_REG_PC)==END
   n=self.word(root+0xf4);stride=12 if homogeneous else 20;base=E+0x6000 if homogeneous else E+0x8000;vertices=[]
   for i in range(n):
    raw=bytes(u.mem_read(base+i*stride,stride));vertices.append({'position_bits':list(struct.unpack('<2I',raw[:8])),'uv_bits':None if homogeneous else list(struct.unpack('<2I',raw[8:16])),'rgba8':list(raw[-4:])})
   rgba=[[self.word(p+off) for off in [0x10,0x14,0x18,0x1c]] for p in [E+0x3000,E+0x3100]]
   assert n==expected['outputs'][held]['count'] and vertices==expected['outputs'][held]['vertices'] and rgba==expected['outputs'][held]['child_rgba_bits']
   draws=[c for c in self.gl if c['name']=='draw-arrays'];blends=[c for c in self.gl if c['name']=='blend'];assert len(draws)==1 and draws[0]['registers'][:3]==[5,0,n];assert len(blends)==1 and blends[0]['registers'][:2]==[1 if root_alpha else 0x302,0x303]
   outputs.append({'held':held,'count':n,'vertices':vertices,'child_rgba_bits':rgba,'draws':draws,'blend':blends,'stop_after':u.mem_read(stop_addr,1)[0]})
  assert all(bytes(u.mem_read(a,len(b)))==b for a,b in protected.items())
  return {'input':dict(stop=stop,root_alpha=root_alpha,child_alpha=child_alpha,homogeneous=homogeneous,opacity=opacity,pose=pose),'outputs':outputs}
def main():
 p=FullRender();cases=[p.full(stop,root,child,h,o,pose) for stop in [0,1] for root in [0,1] for child in [0,1] for h in [0,1] for o in [0,.5,1] for pose in ['plain','rotated']]
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 record={'original_sha256':EXPECTED_SHA,'original_file_and_executed_bodies_unchanged':True,'cases':cases,'scope':'Full original CParticleSystem.Render0x111880 plus full recursiveFillBuffers/short/floatpacking, supplied oneparent/twochildren/valid preallocatedmax-count cache and enabledtexture metadata. GL/blend/bind calls recordingstubs; noactualGPU/allocation/resourceparser/wholeRoomRender/CreepRender. Globalstop0/1 doesnotgate suppliedwrapper:17vertices/onedraw and held childcolor mutations matchdirectFillBuffers exactly. Rootblend flags selectSRC1vsSRC_ALPHA independentofchild own RGB premultiplication. sin/cos andAngPos stubs remain explicit.'};Path('tests/fixtures/native-particle-render-pause-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'held_renders':len(cases)*2,'all_full_wrapper_matches_direct_buffers':True,'original_unchanged':True}))
if __name__=='__main__':main()
