"""Original single-player money plate prefix and insufficient-funds flash.

Texture dimensions/text widths are explicit. GL/text, Objective-C/session,
string formatting and cosf are stubs. The original offset method executes;
plate stops at its first render submission, before avatars/other HUD layers.
Flash executes RenderInfoBarIndicators with draw=false and explicit frame dt.
"""
from native_hud_wallet_reference import WalletProbe
from native_creep_reference import *
from collections import deque
import math

class PlateProbe(WalletProbe):
 def hook(self,u,a,size,data):
  if self.operation=='plate':
   if a==0x36b2ac:self.ret();return
   if a==0x1152d0:
    self.plate=list(struct.unpack('<2f',I(u.reg_read(UC_ARM_REG_R1))+I(u.reg_read(UC_ARM_REG_R2))));u.emu_stop();return
   if a==0x12261c:self.ret(BITS(self.money_width if u.reg_read(UC_ARM_REG_R0)==E+0x1000 else self.spice_width));return
   Probe.hook(self,u,a,size,data);return
  if a==0xd6184:
   u.mem_write(E+0x4d0,I(self.flash_active));u.mem_write(E+0x4d4,F(self.flash_ms));u.mem_write(E+0x438,F(self.dt))
  if a==0x36c43c:self.ret(BITS(math.cos(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0])));return
  if a==0x122658:
   if u.reg_read(UC_ARM_REG_R0)==E+0x1000:self.ink=list(struct.unpack('<4f',I(u.reg_read(UC_ARM_REG_R1))+I(u.reg_read(UC_ARM_REG_R2))+I(u.reg_read(UC_ARM_REG_R3))+u.mem_read(u.reg_read(UC_ARM_REG_SP),4)))
   self.ret();return
  super().hook(u,a,size,data)
 def run_plate(self,width,money_width,spice_width):
  self.operation='plate';self.money_width=money_width;self.spice_width=spice_width;self.plate=None;self.u.mem_write(E,bytes(0x4000));self.u.mem_write(0x40a20c,I(MEMORY+80000));self.u.mem_write(MEMORY+80000,I(width))
  self.u.mem_write(E+0x2ac,I(1));self.u.mem_write(E+0x3ac,I(E+0x1400));self.u.mem_write(E+0x1408,I(400));self.u.mem_write(E+0x464,I(E+0x1000));self.u.mem_write(E+0x45c,I(E+0x1200))
  self.u.reg_write(UC_ARM_REG_SP,STACK-128);self.u.reg_write(UC_ARM_REG_LR,END|1);self.u.reg_write(UC_ARM_REG_R0,E)
  self.u.emu_start(0xd6fe9,END,count=100000);assert self.plate is not None
  return {'width':width,'money_width':money_width,'spice_width':spice_width,'point':self.plate}
 def run_flash(self,active,age,dt):
  self.operation='flash';self.flash_active=active;self.flash_ms=age;self.dt=dt;self.ink=None
  WalletProbe.run(self,1024,55.5,20.25,False)
  return {'active':bool(active),'age_ms':age,'dt_ms':dt,'result':{'active':bool(self.u.mem_read(E+0x4d0,1)[0]),'age_ms':struct.unpack('<f',self.u.mem_read(E+0x4d4,4))[0],'color':self.ink}}

def main():
 p=PlateProbe();plates=[p.run_plate(w,m,s) for w in [480,1024,1280] for m in [0,10,55.5,56.99,57,57.1,120,240,800] for s in [0,20.25,100]]
 flashes=[p.run_flash(active,age,dt) for active in [False,True] for age in [0,1,100,500,1999,2000] for dt in [0,1,16.667,133.333,2000]]
 r={'method':__doc__,'original_sha256':EXPECTED_SHA,'plates':plates,'flashes':flashes,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-hud-plate-reference.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'plates':len(plates),'flashes':len(flashes),'original_unchanged':r['original_unchanged']}))

if __name__=='__main__':main()
