"""Bounded original bolt caller arguments, ball geometry and texture UVs.

Three caller suffixes execute only argument assembly before recording C1.
Supplied heap/tower/enemy/stack records replace earlier selection and service
work. Render runs0xddce8..0xddd58; blend/color/quad are recording stubs.
CalculateUV/SetFlipH/SetFlipV run their original arithmetic. Constructor runs
with texture/allocation/Construct/sound/framework stubs, recording the64px
ball declaration and source anchor. No original renderer/global RNG/game.
"""
from native_creep_reference import *

class AppearanceProbe(Probe):
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a in [self.stop,END]:u.emu_stop();return
  if a==0xdcfbc:
   sp=u.reg_read(UC_ARM_REG_SP)
   self.calls.append({'from':list(struct.unpack('<2f',u.mem_read(r1,8))),'to':list(struct.unpack('<2f',u.mem_read(r2,8))),'enemy_id':r3,'scatter':bool(struct.unpack('<I',u.mem_read(sp+4,4))[0]),'ball':bool(struct.unpack('<I',u.mem_read(sp+8,4))[0])});u.emu_stop();return
  if a==0x11515c:self.calls.append({'blend':[r0,r1]});self.ret();return
  if a==0x36b2ac:self.calls.append({'color':[struct.unpack('<f',I(n))[0] for n in [r0,r1,r2,r3]]});self.ret();return
  if a==0x1152d0:self.calls.append({'quad':[struct.unpack('<f',I(r1))[0],struct.unpack('<f',I(r2))[0]]});self.ret();return
  if a==0x36c6cc:u.mem_write(r0,bytes(r2));self.ret(r0);return
  if a==0x91318:self.ret();return
  if a==0x124ef8:self.ret(E+0x7000);return
  if a==0x36c1bc:self.ret(E+0x4000);return
  if a==0x125cdc:
   sp=u.reg_read(UC_ARM_REG_SP);w,h=struct.unpack('<2I',u.mem_read(sp,8))
   self.calls.append({'texture':self.string(r1),'width':w,'height':h});u.mem_write(r0+8,struct.pack('<2I',w,h));self.ret();return
  if a in [0xdd1e4,0xdd4dc,0x36ca7c]:self.ret();return
  if a==0x36c7cc:self.ret(1);return # Constructor flips omitted; separately exercised below.
  super().hook(u,a,size,data)
 def reset(self,stop=END):
  self.calls=[];self.stop=stop;self.u.mem_write(E,bytes(0x10000));self.u.mem_write(STACK-0x1000,bytes(0x1000))
  self.u.reg_write(UC_ARM_REG_SP,STACK-0x800);self.u.reg_write(UC_ARM_REG_LR,END|1)
 def invoke(self,address,args):
  for r,n in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(r,n)
  self.u.emu_start(address|1,self.stop,count=20000)
  assert self.u.reg_read(UC_ARM_REG_PC) in [self.stop,END,0xdcfbc],hex(self.u.reg_read(UC_ARM_REG_PC))
 def caller(self,name,start,source,target):
  self.reset();u=self.u;sp=u.reg_read(UC_ARM_REG_SP)
  tower=E+0x1000;enemy=E+0x2000;item=E+0x3000
  u.mem_write(item,I(enemy));u.mem_write(enemy+4,I(29));u.mem_write(tower+0x1c8,I(enemy));self.point(enemy+0x190,target)
  if name=='active-defense':
   u.mem_write(sp+0x44,I(E+0x4000));u.mem_write(sp+0x28,I(item));u.mem_write(sp+0x20,I(tower+0x70));self.point(tower+0x70,source)
  elif name=='tesla':
   u.mem_write(sp+0x12c,I(E+0x4000));u.mem_write(sp+0x3c,I(tower));self.point(sp+0x84,source)
  else:
   u.mem_write(sp+0x140,I(E+0x4000));u.mem_write(sp+0x38,I(item));self.point(sp+0x44,source)
  self.invoke(start,[]);assert len(self.calls)==1
  return {'name':name,'start':hex(start),'stop':'0xdcfbc','source':source,'target':target,**self.calls[0]}
 def render(self,source,size,alpha,ball=True,alive=True):
  self.reset(0xddd58);self.point(E+0x60,source);self.u.mem_write(E+0x48,F(alpha));self.u.mem_write(E+0x54,bytes([int(alive)]));self.u.mem_write(E+0x68,I(E+0x4000 if ball else 0));self.u.mem_write(E+0x4008,struct.pack('<2i',*size))
  self.invoke(0xddce8,[E]);return {'source':source,'size':size,'alpha':alpha,'ball':ball,'alive':alive,'calls':self.calls}
 def uv(self,hflip,vflip):
  self.reset();u=self.u;u.mem_write(E+4,I(E+0x4000));u.mem_write(E+8,struct.pack('<2I',64,64));u.mem_write(E+0x4010,struct.pack('<2I',64,64))
  self.invoke(0x1260f8,[E]);
  if hflip:self.invoke(0x1261f4,[E,0])
  if vflip:self.invoke(0x126260,[E,0])
  return {'flip_h':hflip,'flip_v':vflip,'uv':list(struct.unpack('<4f',u.mem_read(E+0x44,16)))}
 def constructor(self,source,scatter,ball):
  self.reset();sp=self.u.reg_read(UC_ARM_REG_SP);self.point(E+0x1000,source);self.point(E+0x1100,(500,300));self.u.mem_write(sp,struct.pack('<3I',0,int(scatter),int(ball)))
  self.invoke(0xdcfe0,[E,E+0x1000,E+0x1100,29])
  return {'source':source,'scatter':scatter,'ball':ball,'calls':self.calls,'stored_source':list(struct.unpack('<2f',self.u.mem_read(E+0x60,8))),'stored_scatter':bool(self.u.mem_read(E+0x6c,1)[0])}

def main():
 p=AppearanceProbe()
 callers=[p.caller(name,start,[140.25,-73.5],[512.5,287.75]) for name,start in [('active-defense',0xe497a),('tesla',0xe6402),('gateway',0xe6850)]]
 renders=[p.render(source,size,alpha,ball,alive) for source in [[0,0],[140.25,-73.5],[1000000,-1000000]] for size in [[64,64],[63,65]] for alpha in [0,0.5,1] for ball,alive in [(True,True),(False,True),(True,False)]]
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'callers':callers,'renders':renders,'uvs':[p.uv(h,v) for h in [False,True] for v in [False,True]],'constructors':[p.constructor([140.25,-73.5],s,b) for s in [False,True] for b in [False,True]],'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-bolt-appearance-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:len(result[k]) for k in ['callers','renders','uvs','constructors']}))

if __name__=='__main__':main()
