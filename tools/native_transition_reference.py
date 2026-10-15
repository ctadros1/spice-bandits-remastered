"""Execute original transition updates with explicit random values.

Only rand is stubbed. The original Init, Open, Close, Update and Node::Update
instructions execute. No UIKit/rendering/service or global RNG parity claim.
"""
from native_creep_reference import *


class TransitionProbe(Probe):
    def __init__(self, values):
        self.values=iter(values)
        super().__init__()

    def hook(self,u,address,size,data):
        if address==0x36c7cc:self.ret(next(self.values));return
        super().hook(u,address,size,data)

    def call(self,address,*args):
        self.u.reg_write(UC_ARM_REG_SP,STACK-32)
        self.u.reg_write(UC_ARM_REG_LR,END|1)
        for register,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(register,value)
        self.u.emu_start(address|1,END,count=100000)

    def state(self):
        u=self.u
        number=lambda address:struct.unpack('<I',u.mem_read(address,4))[0]
        value=lambda address:struct.unpack('<f',u.mem_read(address,4))[0]
        return {'phase':number(E),'start':[value(E+12),value(E+16)],'left':value(E+44),'circle_left':value(E+52),'radius':value(E+56),'opacity':value(E+60),
                'nodes':[{'pos':[value(E+0x2000+i*32),value(E+0x2004+i*32)],'scale':value(E+0x2008+i*32),'left':value(E+0x200c+i*32),'duration':value(E+0x2010+i*32),'max_scale':value(E+0x2014+i*32),'visible':bool(u.mem_read(E+0x2018+i*32,1)[0]),'phase':number(E+0x201c+i*32)} for i in range(16)]}


def scenario(corner,steps):
    values=[(i*31+17)%100 for i in range(48)]
    probe=TransitionProbe(values);u=probe.u
    u.mem_write(E,bytes(128));u.mem_write(E,I(3));u.mem_write(E+20,struct.pack('<2I4f',1024,768,1024/3,768/3,256,192))
    u.mem_write(E+76,I(E+0x5000));u.mem_write(E+0x5008,I(39));u.mem_write(E+0x500c,I(43))
    u.mem_write(E+84,I(E+0x1000));u.mem_write(E+88,I(E+0x1040))
    for i in range(16):
        u.mem_write(E+0x1000+i*4,I(E+0x2000+i*32));u.mem_write(E+0x2000+i*32,bytes(32))
        u.mem_write(E+0x2014+i*32,F(1));u.mem_write(E+0x2018+i*32,b'\x01');u.mem_write(E+0x201c+i*32,I(3))
    probe.call(0xb29e4,E,0,0,corner)
    result={'corner':corner,'random_values':values,'initial':probe.state(),'frames':[]}
    for i in range(200):
        dt=steps[i%len(steps)]
        probe.call(0xb25d4,E,BITS(dt));state=probe.state()
        result['frames'].append({'dt':dt,'state':state})
        if state['phase']==1:break
    assert state['phase']==1
    probe.call(0xb2a90,E,0,9)
    result['close']=probe.state()
    result['reveal_frames']=[]
    for i in range(200):
        dt=steps[i%len(steps)]
        probe.call(0xb25d4,E,BITS(dt));state=probe.state()
        result['reveal_frames'].append({'dt':dt,'state':state})
        if state['phase']==3:break
    assert state['phase']==3
    return result


if __name__=='__main__':
    cases=[scenario(0,[1/60]),scenario(3,[0.03]),scenario(7,[0.01,0.023,0.041])]
    result={'original_sha256':EXPECTED_SHA,'method':__doc__,'texture':[39,43],'size':[1024,768],'cases':cases}
    Path('tests/fixtures/native-transition-reference.json').write_text(json.dumps(result,indent=2)+'\n')
    print('Original transition cases:',len(cases),'frames:',sum(len(c['frames'])+len(c['reveal_frames']) for c in cases))
