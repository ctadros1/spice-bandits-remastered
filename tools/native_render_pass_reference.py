"""Original running-room/map/air routing with supplied records and draw stubs.

Executes full CRoom::Render0xd4f04, CMap::Render0x104088, RenderObjects,
RenderAfter and CCreepManager::RenderAllAirCreeps. Source sorting/vector
copy loops execute. Supplied ready/enabled/map and optional preview/effect
records replace constructors. Drawing, GUI, preview updates, OpenGL and
virtual object callbacks are recording stubs; no pixels, timers, services,
concurrency, complete object lifetimes or whole game are executed.
"""
from native_air_pass_reference import *


class RenderProbe(AirProbe):
 DRAW={0x103ca4:'segments',0x95dd8:'water',0x104254:'animated-object',0xb7c78:'tutorial-marks',0x10406c:'selection',0x1043b4:'preview-hexes',0x104fb0:'grid',0xe8430:'tower-preview',0x10f3a0:'global-animation-update',0x10f54c:'global-animation-render',0x111880:'global-particle',0x9e0bc:'environment',0x9d97c:'decals',0x9edd4:'footsteps',0xd5088:'update-tower-preview',0xd5648:'update-mine-preview',0xd56c0:'update-portal-preview',0xf0d30:'tower-panel-after',0xe9eac:'tower-info',0xfec68:'floating-indicators',0xfd53c:'bubbles',0x105a04:'backgrounds',0xd5738:'gui',0xd60b0:'shop-fade'}
 def reset(self,stop=END):
  super().reset(stop);self.imports=[]
 def hook(self,u,a,size,data):
  if 0x36b000<=a<0x36d000:self.imports.append(hex(a));self.imports=self.imports[-20:]
  if a in [0x104088,0x103ce8,0xfbe8c]:self.calls.append({'method':{0x104088:'map-render',0x103ce8:'map-after',0xfbe8c:'air-manager'}[a]})
  if a in self.DRAW:self.calls.append({'method':self.DRAW[a]});self.ret();return
  if a in [0x11512c,0x1151a0,0x1151cc,0x36b3cc,0x1102f0,0x1103e0,0x11044c]:self.ret();return
  if a in [0xe97d0,0x9b5c8,0x9cd3c]:
   key,address={0xe97d0:('tower',E+0x30000),0x9b5c8:('mine',E+0x33000),0x9cd3c:('portal',E+0x34000)}[a]
   self.ret(address if self.flags.get(key,False) else 0);return
  super().hook(u,a,size,data)
 def frame(self,types,flags):
  # AirProbe.route supplies the actor/resource/vtable records; discard its
  # initial routing trace before executing the original room entry point.
  self.route(types);self.calls=[];self.flags=flags
  room=E+0x70000;self.u.mem_write(room,bytes(0x1000))
  self.u.mem_write(room+0xc,I(0 if flags.get('no_map') else E))
  self.u.mem_write(room+0x18,bytes([0 if flags.get('disabled') else 1]))
  self.u.mem_write(room+0x2f5,bytes([0 if flags.get('not_ready') else 1]));self.u.mem_write(room+0x382,b'\x01')
  if flags.get('tower_panel'):self.u.mem_write(room+0x2b8,I(E+0x74000))
  ground=[E+0x10000+i*0x400 for i,t in enumerate(types) if t==1]
  self.u.mem_write(E+0x50,struct.pack('<3I',E+0x8000,E+0x8000+4*len(ground),E+0x9000))
  if ground:self.u.mem_write(E+0x8000,struct.pack('<'+'I'*len(ground),*ground))
  self.u.mem_write(E+0x68,struct.pack('<3I',E+0x9000,E+0x9000,E+0xa000))
  self.u.mem_write(E+0x74,I(E+0x6f000))
  for flag,offset,address in [('water',0x178,E+0x6f800),('tutorial',0x2a0,E+0x6f900),('environment',0x78,E+0x6e000)]:
   self.u.mem_write(E+offset,I(address if flags.get(flag) else 0))
  self.u.mem_write(E+0x168,bytes([int(flags.get('grid',False))]))
  self.u.mem_write(E+0x30054,b'\x01');self.u.mem_write(E+0x300f0,I(E+0x38000));self.u.mem_write(E+0x38024,F(100));self.u.mem_write(E+0x300fc,F(1))
  for flag,offset,storage,objects in [('animated',0x94,E+0x4000,[E+0x68000,E+0x69000]),('global_anim',0x7c,E+0x5000,[E+0x6a000,E+0x6b000]),('global_particles',0x88,E+0x6000,[E+0x6c000,E+0x6d000])]:
   count=len(objects) if flags.get(flag) else 0
   self.u.mem_write(E+offset,struct.pack('<2I',storage,storage+4*count))
   self.u.mem_write(storage,struct.pack('<2I',*objects))
  self.invoke(0xd4f04,[room])
  return {'calls':self.calls,'map_lock':self.u.mem_read(E+0x4c,1)[0]}


def main():
 p=RenderProbe();cases=[]
 for name,types,flags in [('empty',[],{}),('ground',[1,1],{}),('air',[2,2],{}),('mixed',[1,2,1,2],{}),('not-ready',[1,2],{'not_ready':True}),('disabled',[1,2],{'disabled':True}),('no-map',[1,2],{'no_map':True}),('preview',[1,2],{'tower':True,'mine':True,'portal':True,'grid':True}),('effects',[1,2],{'water':True,'tutorial':True,'animated':True,'global_anim':True,'global_particles':True,'environment':True,'tower_panel':True})]:
  try:output=p.frame(types,flags)
  except Exception:
   print(json.dumps({'failed_case':name,'last_calls':p.calls[-16:],'imports':p.imports}),flush=True);raise
  cases.append({'name':name,'types':types,'flags':flags,'output':output})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-render-pass-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
