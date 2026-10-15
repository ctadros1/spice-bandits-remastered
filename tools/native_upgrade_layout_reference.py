"""Original upgrade item placement and right-side panel mirroring.

LoadItemAtIndex executes with explicit tablet/phone grid globals and authored
NIB element frames. Allocation, Objective-C/session/NIB calls, notifications,
threading, image assignment and transforms are recorded stubs. The recursive
next-index send stops; each following index is invoked explicitly. The selection scroll function additionally executes against explicit768/1024/600px root heights,187px item height and content offsets. No UIKit
layout, text rasterizer, transition compositor or whole app executes.
"""
from native_creep_reference import *

class UpgradeProbe(Probe):
    def __init__(self):
        super().__init__()
        symbol=next(s for s in json.load(open('original/analysis/decrypted-symbols.json')) if s['name']=='_OBJC_IVAR_$_UpgradesViewController.upgradesKeysArray' and s['value'])
        self.keys_offset=struct.unpack('<I',self.u.mem_read(symbol['value'],4))[0]
    def hook(self,u,a,size,data):
        if a in (0x36bebc,0x36becc,0x36ca7c):self.ret(0);return
        if a==0x36cadc:self.ret(u.reg_read(UC_ARM_REG_R0)%u.reg_read(UC_ARM_REG_R1));return
        if a==0x36abec:
            pointer=u.reg_read(UC_ARM_REG_R0);u.mem_write(pointer,F(-1)+F(0)+F(0)+F(1)+F(0)+F(0));self.ret(pointer);return
        if a==0x36be6c:
            receiver,selector,arg=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)];name=self.string(selector)
            if name=='intValue':self.ret(self.index);return
            if name=='count':self.ret(20);return
            if name=='view':self.ret(E+0x3000);return
            if name=='upgradesKeysArray':self.ret(E+0x5000);return
            if name in ('itemPanelImageView','itemPanelNameLabel','costLabel','itemPanelDescriptionLabel'):
                self.ret(E+{'itemPanelImageView':0x3100,'itemPanelNameLabel':0x3200,'costLabel':0x3300,'itemPanelDescriptionLabel':0x3400}[name]);return
            if name=='frameX':self.ret(BITS(self.frames.get(receiver,[0,0])[0]));return
            if name in ('setFrameX:','setFrameY:'):
                self.frames.setdefault(receiver,[0,0])[0 if name=='setFrameX:' else 1]=struct.unpack('<f',I(arg))[0]
            if name=='setTransform:':self.mirrored=True
            self.ret(E+0x6000);return
        super().hook(u,a,size,data)
    def run(self,phone):
        self.u.mem_write(E,bytes(0x7000));self.u.mem_write(E+self.keys_offset,I(E+0x5000))
        # These image addresses are pointer-table slots, not the globals.
        target=lambda a:struct.unpack('<I',self.u.mem_read(a,4))[0]
        self.u.mem_write(target(0x47bffc),bytes([0]))
        for slot,value in zip(range(0x47c000,0x47c01c,4),[0,0,4 if phone else 5,1 if phone else 2,120 if phone else 150,107 if phone else 137,phone]):self.u.mem_write(target(slot),I(value))
        result=[]
        for i in range(20):
            self.index=i;self.mirrored=False;self.frames={E+0x3000:[0,0],E+0x3100:[5,23],E+0x3200:[171,70],E+0x3300:[400,70],E+0x3400:[171,94]}
            self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
            self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,0);self.u.reg_write(UC_ARM_REG_R2,E+0x4000)
            
            try:self.u.emu_start(0x319cd,END,count=100000)
            except UcError:
                print('probe failed',i,hex(self.u.reg_read(UC_ARM_REG_PC)),[hex(self.u.reg_read(r)) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)])
                raise
            assert self.u.reg_read(UC_ARM_REG_PC)==END
            result.append({'index':i,'position':self.frames[E+0x3000],'mirrored':self.mirrored,'panel_x':self.frames[E+0x3100][0],'name_x':self.frames[E+0x3200][0],'cost_x':self.frames[E+0x3300][0],'description_x':self.frames[E+0x3400][0]})
        return result

class ScrollProbe(Probe):
 def __init__(self):
  super().__init__()
  symbol=next(s for s in json.load(open('original/analysis/decrypted-symbols.json')) if s['name']=='_OBJC_IVAR_$_UpgradesViewController.scrollView' and s['value'])
  self.offset=struct.unpack('<I',self.u.mem_read(symbol['value'],4))[0]
 def hook(self,u,a,size,data):
  if a==0x36be9c:
   self.u.mem_write(u.reg_read(UC_ARM_REG_R0),struct.pack('<2f',0,self.scroll));self.ret();return
  if a==0x36be6c:
   r0,r1,r2,r3=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)];n=self.string(r1)
   v=E+0x6000
   if n=='object':v=E+0x1000
   elif n=='view':v=E+0x2000 if r0==E+0x1000 else E+0x3000
   elif n=='deviceType':v=self.phone
   elif n=='frameY':v=BITS(self.row)
   elif n=='frameHeight':v=BITS(187 if r0==E+0x2000 else self.height)
   elif n=='setContentOffset:animated:':self.actions.append([struct.unpack('<f',I(r2))[0],struct.unpack('<f',I(r3))[0]])
   self.ret(v);return
  super().hook(u,a,size,data)
 def run(self,row,scroll,height,phone=0):
  self.row,self.scroll,self.height,self.phone=row,scroll,height,phone;self.actions=[]
  self.u.mem_write(E,bytes(0x7000));self.u.mem_write(E+self.offset,I(E+0x5000))
  self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
  self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,0);self.u.reg_write(UC_ARM_REG_R2,E+0x4000)
  self.u.emu_start(0x31809,END,count=100000)
  return {'row':row,'scroll':scroll,'height':height,'actions':self.actions}

p=UpgradeProbe();scroll=ScrollProbe();record={'method':__doc__,'original_sha256':EXPECTED_SHA,'tablet':p.run(0),'phone':p.run(1),'selection_scroll':[scroll.run(row,offset,height) for row in [0,137,274,411] for offset in [-30,0,40,137,411,600] for height in [600,768,1024]],'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-upgrade-layout-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'tablet_items':20,'phone_items':20,'sample':record['tablet'][3],'scroll_cases':len(record['selection_scroll']),'original_unchanged':record['original_unchanged']}))
