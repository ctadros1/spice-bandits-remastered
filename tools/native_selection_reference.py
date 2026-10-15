"""Original map selection router, panel guard, inactive manager and oval math.

Runs full0x10406c/0xf0c5c/0xe9e70/0xe8130 with supplied map/panel/tower
records and vector storage. GL blend/color and oval submissions are recorded
stubs. No original input, timers, resource loading, GPU or complete game.
"""
from native_map_order_reference import *


class SelectionProbe(OrderProbe):
 def hook(self,u,a,size,data):
  if a==0xe8130:
   actor=u.reg_read(UC_ARM_REG_R0);self.draws.append({'label':(actor-E-0x4000)//0x400,'alpha':struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R1)))[0],'ovals':[]})
  if a==0x36b2ac:
   self.color=[struct.unpack('<f',I(u.reg_read(r)))[0] for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]];self.ret();return
  if a==0x11515c:self.ret();return
  if a in [0x114b74,0x114a84]:
   args=[struct.unpack('<f',I(u.reg_read(r)))[0] for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
   self.draws[-1]['ovals'].append({'filled':a==0x114b74,'origin':args[:2],'axes':args[2:],'color':self.color[:]});self.ret();return
  super().hook(u,a,size,data)
 def selection(self,flags,alpha,inactive):
  self.reset();self.draws=[];self.color=[]
  self.u.mem_write(E+0x118,I(E+0x1000 if flags.get('panel',True) else 0))
  self.u.mem_write(E+0x1062,bytes([int(flags.get('visible',True))]))
  self.u.mem_write(E+0x1048,F(alpha))
  self.u.mem_write(E+0x105c,I(E+0x4000 if flags.get('tower',True) else 0))
  specs=[{'active':True,'positioned':True,'resource':flags.get('resource',True)}]+inactive
  for i,spec in enumerate(specs):
   actor=E+0x4000+i*0x400;resource=E+0x8000+i*0x100
   self.u.mem_write(actor+0x40,bytes([int(spec.get('active',False))]))
   self.u.mem_write(actor+0x54,bytes([int(spec.get('positioned',True))]))
   self.u.mem_write(actor+0x4c,struct.pack('<2f',120+i*30,170+i*15))
   self.u.mem_write(actor+0xf0,I(resource if spec.get('resource',True) else 0))
   self.u.mem_write(resource+0x24,F(2000+i*500));self.u.mem_write(actor+0xfc,F(i*125))
  start=E+0x3000
  self.u.mem_write(0x47ed08,struct.pack('<2I',start,start+4*len(inactive)))
  if inactive:self.u.mem_write(start,struct.pack('<'+'I'*len(inactive),*[E+0x4000+(i+1)*0x400 for i in range(len(inactive))]))
  self.u.mem_write(0x40a284,I(MEMORY+90000));self.u.mem_write(0x40a288,I(MEMORY+90004));self.u.mem_write(MEMORY+90000,F(.062)+F(1.440000057220459))
  self.invoke(0x10406c,[E])
  return self.draws


def main():
 p=SelectionProbe();cases=[]
 for flags in [{},{'panel':False},{'visible':False},{'tower':False},{'resource':False}]:
  for alpha in [0,.25,.5,1]:
   for inactive in [[],[{'active':False,'positioned':True},{'active':True,'positioned':True},{'active':False,'positioned':False}]]:
    cases.append({'flags':flags,'alpha':alpha,'inactive':inactive,'output':p.selection(flags,alpha,inactive)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-selection-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'calls':sum(len(c['output']) for c in cases),'ovals':sum(len(d['ovals']) for c in cases for d in c['output']),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
