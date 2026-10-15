"""Original mode-item pulse and render submissions with explicit input structs.

Update executes its initial animation and final color/pulse blocks, skipping
configuration/service/string setup at0x85126..0x85a96. Text color setters
execute against explicit constructor palettes; sinf is a host stub. Render
executes against supplied texture metadata and
text metrics, with GL/text/map calls recorded. No original raster is executed.
"""
from native_creep_reference import *
from collections import deque
import math

class ModeEffectProbe(Probe):
 def hook(self,u,a,size,data):
  self.trace.append(a)
  if self.operation=='update':
   if self.pending_color is not None and a==self.pending_color['return']:
    call=self.pending_color;self.colors.append({'target':self.targets[call['object']],'alpha':call['alpha'],'rgba':list(struct.unpack('<4f',u.mem_read(call['object']+12,16)))})
    self.pending_color=None
   if a==0x85126:u.reg_write(UC_ARM_REG_PC,0x85a97);return
   if a==0x85dd0:u.emu_stop();return
   if a==0x36c88c:
    self.ret(BITS(math.sin(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0])));return
   if a in (0x12262c,0x12267c):
    r0,r1=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1]]
    # changeColorByAlpha receives this in r0 and alpha at stack+4.
    alpha=struct.unpack('<f',I(r1) if a==0x12262c else u.mem_read(u.reg_read(UC_ARM_REG_SP)+4,4))[0]
    self.pending_color={'object':r0,'alpha':alpha,'return':u.reg_read(UC_ARM_REG_LR)&~1}
  else:
   r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
   if a==0x36b2ac:
    self.color=list(struct.unpack('<4f',b''.join(I(x) for x in [r0,r1,r2,r3])));self.ret();return
   if a in (0x11515c,0x36b22c):self.ret();return
   if a in (0x1152d0,0x116c30):
    self.draws.append({'kind':'image' if a==0x1152d0 else 'text','target':r0-E,'point':list(struct.unpack('<2f',I(r1)+I(r2))),'color':self.color[:]});self.ret();return
   if a==0x1156f4:
    self.draws.append({'kind':'plate','texture_id':r0,'values':list(struct.unpack('<8f',I(r1)+I(r2)+I(r3)+u.mem_read(u.reg_read(UC_ARM_REG_SP),20))),'color':self.color[:]});self.ret();return
   if a==0x36bfac:self.ret();return
   if a==0x8afb0:self.ret(E+0x6000);return
   if a in (0x36c04c,0x36c06c):self.ret();return
   if a==0x122700:self.ret(BITS(4));return
   if a==0x12261c:self.ret(BITS(self.title_width));return
  super().hook(u,a,size,data)
 def update(self,mode,opened,steps):
  self.operation='update';self.trace=deque(maxlen=24);self.u.mem_write(E,bytes(0x8000))
  self.point(E+0x54,(360,369));self.point(E+0x5c,(51,-224));self.u.mem_write(E+0x74,I(opened));self.u.mem_write(E+0x8c,I(mode))
  self.targets={};self.pending_color=None
  orange=(0.9330000281333923,0.5058000087738037,0,1);blue=(0,0.4156000018119812,0.6116999983787537,1)
  for offset,color in [(0x2d8,orange),(0x318,(1,1,1,1)),(0x328,(0,0,0,1))]:self.u.mem_write(E+offset,struct.pack('<4f',*color))
  for off in [8,12,16,20,24,28,32,36,40,44,48,52,64,72]:
   obj=E+0x5000+off*32;self.targets[obj]=off;self.u.mem_write(E+off,I(obj))
   color=blue if off in [16,32,48] else orange if off in [20,36,52] else (0.5839999914169312,0.7019000053405762,0.7490000128746033,.8) if off in [64,72] else (1,1,1,1)
   self.u.mem_write(obj+12,struct.pack('<4f',*color))
  frames=[]
  for dt in steps:
   self.colors=[];self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
   for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,BITS(dt),0,0]):self.u.reg_write(r,v)
   self.u.mem_write(STACK-32,bytes(12));self.u.emu_start(0x84f29,END,count=100000)
   assert self.u.reg_read(UC_ARM_REG_PC)==0x85dd0
   state={k:struct.unpack('<f',self.u.mem_read(E+o,4))[0] for k,o in [('phase',0x6c),('geometry_alpha',0x70),('pulse_alpha',0x78),('flash_ms',0x7c),('text_phase',0x80),('text_alpha',0x84)]}
   frames.append({'dt_ms':dt,'state':state,'colors':self.colors})
  return {'mode':mode,'opened':bool(opened),'frames':frames}
 def render(self,mode,opened,phase,geometry_alpha,text_alpha,pulse_alpha,star=False,multiplayer=False,title_width=120):
  self.title_width=title_width
  self.operation='render';self.trace=deque(maxlen=24);self.draws=[];self.color=[1]*4;self.u.mem_write(E,bytes(0x8000));self.u.mem_write(E+0x50,I(E+0x2000))
  self.point(E+0x64,(411,145))
  for off,value in [(0x6c,phase),(0x70,geometry_alpha),(0x78,pulse_alpha),(0x84,text_alpha)]:self.u.mem_write(E+off,F(value))
  self.u.mem_write(E+0x74,I(opened));self.u.mem_write(E+0x8c,I(mode))
  self.u.mem_write(E+0x89,bytes([int(multiplayer)]))
  if star:
   self.u.mem_write(E+0x206c,I(E+0x2500));self.u.mem_write(E+0x2500,I(E+0x2510)+I(E+0x2514));self.u.mem_write(E+0x2510,I(E+0x2600));self.u.mem_write(E+0x2633,b'\x01')
  for index,off in enumerate([4,8,12,16,20,24]):
   tex=E+0x3000+index*0x100;self.u.mem_write(E+0x2000+off,I(tex));self.u.mem_write(tex+4,I(tex+0x80));self.u.mem_write(tex+0x80,I(100+index));self.u.mem_write(tex+8,I(364 if index<3 else 71)+I(98 if index<3 else 71));self.u.mem_write(tex+0x44,F(.1)+F(.2)+F(.3)+F(.4))
  self.u.mem_write(E+0x6014,I(E+0x3800));self.u.mem_write(E+0x3808,I(58)+I(58))
  for off in [8,12,16,20,24,28,32,36,40,44,48,52,64]:self.u.mem_write(E+off,I(E+0x5000+off))
  self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E)
  try:self.u.emu_start(0x8621d,END,count=100000)
  except UcError:print('render failed',hex(self.u.reg_read(UC_ARM_REG_PC)),list(map(hex,self.trace)));raise
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'mode':mode,'opened':bool(opened),'phase':phase,'geometry_alpha':geometry_alpha,'text_alpha':text_alpha,'pulse_alpha':pulse_alpha,'star':star,'multiplayer':multiplayer,'title_width':title_width,'draws':self.draws}

def main():
 p=ModeEffectProbe();updates=[p.update(mode,opened,steps) for mode in [1,2,3] for opened in [False,True] for steps in [[0,1,99,50,150,150,150], [16.667]*40,[300,1,12.5,12.5,25,25,75,150,1000]]]
 renders=[p.render(mode,opened,phase,g,t,pulse) for mode in [1,2,3] for opened in [False,True] for phase,g,t,pulse in [(0,0,0,0),(.5,.5,.25,.2),(1,1,.5,.45),(1,1,1,.95)]]
 renders.extend(p.render(3,True,1,1,1,.95,star=True) for _ in range(1))
 renders.extend(p.render(mode,True,1,1,1,.95,star=star,multiplayer=True,title_width=width) for mode in [1,2,3] for width in [80,180] for star in ([False,True] if mode==3 else [False]))
 record={'method':__doc__,'original_sha256':EXPECTED_SHA,'updates':updates,'renders':renders,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-mode-effect-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'updates':len(updates),'frames':sum(len(c['frames']) for c in updates),'renders':len(renders),'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
