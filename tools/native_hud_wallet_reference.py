"""Original HUD currency positions with supplied font widths and session values.

RenderInfoBarIndicators executes with draw=false. Session XP/spice, formatting,
text width/color and Objective-C calls are explicit stubs. No CoreText measurement,
original font raster, renderer or whole application is executed.
"""
from native_creep_reference import *
from collections import deque
import ctypes
SNPRINTF=ctypes.CDLL(None).snprintf
SNPRINTF.argtypes=[ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
SNPRINTF.restype=ctypes.c_int

class WalletProbe(Probe):
 def hook(self,u,a,size,data):
  self.trace.append(a)
  r0,r1=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1)]
  if a==0x36be6c:
   name=self.string(r1)
   self.ret(self.spice if name=='spice' else BITS(self.remaining) if name=='tonextlevel' else BITS(self.xp) if name=='xppoints' else self.lower if name=='levelpoints' else self.level if name=='intValue' else E+0x2000 if name in ('player','userData','objectForKey:') else 0);return
  if a==0x12261c:self.ret(BITS(self.money_width if r0==E+0x1000 else self.spice_width if r0==E+0x1200 else self.xp_width if r0==E+0x1500 else 0));return
  if a in (0x1152d0,0x116c30):
   self.draws.append({'kind':'image' if a==0x1152d0 else 'text','target':hex(r0),'point':list(struct.unpack('<2f',I(r1)+I(u.reg_read(UC_ARM_REG_R2))))});self.ret();return
  if a==0x1156f4:
   values=list(struct.unpack('<8f',I(r1)+I(u.reg_read(UC_ARM_REG_R2))+I(u.reg_read(UC_ARM_REG_R3))+u.mem_read(u.reg_read(UC_ARM_REG_SP),20)))
   self.draws.append({'kind':'fill','values':values});self.ret();return
  if a in (0x122658,0x1224b4,0x36ca7c,0x36b2ac):self.ret();return
  if a in (0x36c89c,0x36c8ac):
   fmt=self.string(u.reg_read(UC_ARM_REG_R2) if a==0x36c89c else r1)
   value=''
   if 'sp' in fmt:
    output=ctypes.create_string_buffer(128)
    if 'f' in fmt:argument=ctypes.c_double(struct.unpack('<d',I(u.reg_read(UC_ARM_REG_R3))+u.mem_read(u.reg_read(UC_ARM_REG_SP),4))[0])
    else:argument=ctypes.c_int(u.reg_read(UC_ARM_REG_R3) if a==0x36c89c else u.reg_read(UC_ARM_REG_R2))
    SNPRINTF(output,128,fmt.encode(),argument);value=output.value.decode();self.formats.append({'format':fmt,'argument':argument.value,'text':value})
   u.mem_write(r0,value.encode()+b'\x00');self.ret(len(value));return
  if a in (0x36c04c,0x36c05c,0x36c06c,0x36bfec,0x8ab80):self.ret(r0);return
  if a==0x8ac28:self.ret(E+0x3000);return
  if a==0x36c97c:self.ret(0);return
  super().hook(u,a,size,data)
 def run(self,width,money_width,spice_width,phone,spice=0,draw=False,xp=0,remaining=10,lower=0,level=1,xp_width=50):
  self.trace=deque(maxlen=24);self.formats=[];self.draws=[];self.spice=spice;self.xp=xp;self.remaining=remaining;self.lower=lower;self.level=level;self.xp_width=xp_width;self.money_width=money_width;self.spice_width=spice_width;self.u.mem_write(E,bytes(0x4000))
  self.u.mem_write(E+0x3000,I(E+0x3100))
  self.u.mem_write(0x40a20c,I(MEMORY+80000));self.u.mem_write(MEMORY+80000,I(width))
  self.u.mem_write(E+0x464,I(E+0x1000));self.u.mem_write(E+0x45c,I(E+0x1200));self.u.mem_write(E+0x1dd,bytes([int(phone)]))
  self.u.mem_write(E+0x4b8,F(-1))
  self.u.mem_write(E+0x404,I(E+0x1400));self.u.mem_write(E+0x408,I(E+0x1800));self.u.mem_write(E+0x458,I(E+0x1500));self.u.mem_write(E+0x1804,I(E+0x2800));self.u.mem_write(E+0x1808,I(66)+I(7));self.u.mem_write(E+0x4b4,F(-1))
  self.u.mem_write(E+0x1844,F(302/1024)+F(368/1024)+F(328/512)+F(335/512))
  self.u.reg_write(UC_ARM_REG_SP,STACK-128);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,int(draw))
  try:self.u.emu_start(0xd6185,END,count=100000)
  except UcError:print('wallet failed',hex(self.u.reg_read(UC_ARM_REG_PC)),[hex(a) for a in self.trace]);raise
  assert self.u.reg_read(UC_ARM_REG_PC)==END
  return {'width':width,'money_width':money_width,'spice_width':spice_width,'phone':phone,'spice':spice,'xp':xp,'remaining':remaining,'lower':lower,'level':level,'xp_width':xp_width,'draws':self.draws,'spice_formats':self.formats,'money_position':list(struct.unpack('<2f',self.u.mem_read(E+0x1098,8)))}

def main():
 p=WalletProbe();cases=[p.run(w,m,s,phone) for w in [480,1024,1280] for m in [0,55.5,120] for s in [0,20.25,60] for phone in [False,True]]
 record={'method':__doc__+' Selected native format strings/arguments use an explicit current-host libc snprintf stub. XP draws additionally record renderer calls against supplied66x7 fill/UV metadata; original raster is not executed.','original_sha256':EXPECTED_SHA,'cases':cases,'spice_cases':[p.run(1024,55.5,20.25,False,value) for value in [0,1,999,1000,1001,1499,1500,9999,10000,12345,1000000]],'xp_cases':[p.run(1024,55.5,20.25,phone,draw=True,xp=xp,remaining=remaining,lower=lower,level=level,xp_width=width) for xp,remaining,lower,level in [(0,10,0,1),(7.5,2.5,0,1),(10,0,0,1),(10,30,10,2),(11,29,10,2)] for phone in [False,True] for width in [30,55.5]],'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-hud-wallet-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sample':cases[8],'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
