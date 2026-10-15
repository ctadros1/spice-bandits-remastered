"""Original message fade/quad/text and button/hitbox submissions.

Explicit512-square background,256x128 button textures, text widths, viewport,
alpha and timestep. GL, text metrics/color, clicks and sound are stubs. No
texture loader, text rasterizer, notification owner or whole app executes.
"""
from native_creep_reference import *

class MessageProbe(Probe):
    def hook(self,u,a,size,data):
        if a in (0x11515c,0x36b2ac,0x12262c,0xa9e8c,0x1206e4):self.ret(0);return
        if a==0x12261c:self.ret(BITS(self.text_widths.get(u.reg_read(UC_ARM_REG_R0),30)));return
        if a in (0x1152d0,0x116c30):
            self.draws.append({'kind':'quad' if a==0x1152d0 else 'text','id':u.reg_read(UC_ARM_REG_R0),'position':[struct.unpack('<f',I(u.reg_read(r)))[0] for r in (UC_ARM_REG_R1,UC_ARM_REG_R2)]});self.ret(0);return
        if a==0x110c50:
            self.hits.append([u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)]);self.ret(0);return
        super().hook(u,a,size,data)
    def initialize(self,size):
        self.u.mem_write(E,bytes(0x6000));self.draws=[];self.hits=[];self.text_widths={}
        self.u.mem_write(0x40a20c,I(MEMORY+80000));self.u.mem_write(0x40a204,I(MEMORY+80004));self.u.mem_write(MEMORY+80000,I(size[0])+I(size[1]))
    def call(self,a,args):
        self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
        for r,v in zip((UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3),args):self.u.reg_write(r,v)
        self.u.emu_start(a|1,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
    def message(self,size,alpha,dt,closing):
        self.initialize(size);self.u.mem_write(E,bytes([closing]));self.u.mem_write(E+4,F(alpha))
        self.u.mem_write(E+8,I(E+0x1000)+I(E+0x2000)+I(E+0x2100));self.u.mem_write(E+0x1008,I(512)+I(512))
        self.u.mem_write(E+0x20,I(E+0x4000)+I(E+0x4000));self.text_widths={E+0x2000:0,E+0x2100:300}
        self.call(0xa967c,[E,BITS(dt)])
        return {'alpha':struct.unpack('<f',self.u.mem_read(E+4,4))[0],'finished':bool(self.u.mem_read(E+1,1)[0]),'draws':self.draws}
    def button(self,size,index,alpha):
        self.initialize(size);self.u.mem_write(E,I(E+0x2000)+I(E+0x1000)+I(E+0x1100)+F(alpha))
        self.u.mem_write(E+0x18,F(-85 if index==0 else 85)+F(100))
        self.u.mem_write(E+0x1008,I(256)+I(128));self.u.mem_write(E+0x1108,I(256)+I(128))
        self.call(0xa8f58,[E]);return {'draws':self.draws,'hits':self.hits}

p=MessageProbe();messages=[];buttons=[]
for size in ((1024,768),(1280,960)):
    for alpha in (0,0.2,0.8,1):
        for dt in (0,0.1,0.3):
            for closing in (0,1):messages.append({'size':size,'alpha':alpha,'dt':dt,'closing':closing,'result':p.message(size,alpha,dt,closing)})
    for index in (0,1):
        for alpha in (0,0.19,0.2,0.20001,0.5,1):buttons.append({'size':size,'index':index,'alpha':alpha,'result':p.button(size,index,alpha)})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'messages':messages,'buttons':buttons,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-message-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'message_frames':len(messages),'button_frames':len(buttons),'original_unchanged':record['original_unchanged']}))
