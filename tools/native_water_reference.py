"""Bounded preserved ARM water/Perlin execution, without an iOS renderer.

The original constructors, Perlin initialization/noise, water update and
water vertex generation execute. Allocation/OpenGL are stubs; rand/srand and
float sin/cos use this host's Darwin libc. The historical Apple rand source
has the same default Park-Miller recurrence, but the original iOS dylib and
whole-game random call sequence are not executed. Texture UV bounds are
explicit inputs, not a claim that texture loading/compositing matches iOS.
"""
from native_creep_reference import *
import ctypes

PERLIN=E+0x5000
VERTICES=E+0x18000
LIBC=ctypes.CDLL('/usr/lib/libSystem.B.dylib')
LIBC.sinf.argtypes=[ctypes.c_float];LIBC.sinf.restype=ctypes.c_float
LIBC.cosf.argtypes=[ctypes.c_float];LIBC.cosf.restype=ctypes.c_float
GL={0x36b55c,0x36b54c,0x36b60c,0x36b1ac,0x36b3cc,0x36b29c,
    0x36b3dc,0x36b63c,0x36b5cc,0x36b3ac,0x36b39c,0x11515c,0x11520c}

class WaterProbe(Probe):
    def __init__(self):
        self.random_values=[];self.draw_count=0;self.colors=[]
        super().__init__()

    def hook(self,u,address,size,data):
        value=u.reg_read(UC_ARM_REG_R0)
        if address==0x36c8bc:LIBC.srand(value);self.seed=value;self.ret();return
        if address==0x36c7cc:
            value=LIBC.rand();self.random_values.append(value);self.ret(value);return
        if address in [0x36c1bc,0x36c1ac]:self.ret(PERLIN if address==0x36c1bc else VERTICES);return
        if address in [0x36c88c,0x36c43c]:
            arg=struct.unpack('<f',I(value))[0]
            self.ret(BITS(LIBC.sinf(arg) if address==0x36c88c else LIBC.cosf(arg)));return
        if address==0x36b3bc:self.draw_count=u.reg_read(UC_ARM_REG_R2);self.ret();return
        if address==0x36b2ac:
            self.colors.append([struct.unpack('<f',I(u.reg_read(r)))[0] for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]])
            self.ret();return
        if address in GL or address==0x36ca7c:self.ret();return
        super().hook(u,address,size,data)

    def call(self,address,*args):
        self.stop=END;self.u.reg_write(UC_ARM_REG_SP,STACK-32);self.u.reg_write(UC_ARM_REG_LR,END|1)
        for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(r,v)
        self.u.emu_start(address|1,END,count=2000000)
        assert self.u.reg_read(UC_ARM_REG_PC)==END,'bounded call did not return'

    def setup(self,plane=(1024,1024),segments=(15,28),water_uv=(0,1,0,1),mask_uv=(0,1,0,1)):
        self.u.mem_write(E,bytes(128));self.call(0x95c0c,E)
        self.u.mem_write(E,struct.pack('<4f',*plane,*segments))
        for offset,address,uv in [(0x14,E+0x2000,water_uv),(0x18,E+0x2100,mask_uv)]:
            self.u.mem_write(E+offset,I(address));self.u.mem_write(address+4,I(address+0x100));self.u.mem_write(address+0x100,I(1))
            self.u.mem_write(address+0x44,struct.pack('<4f',*uv))
        self.u.mem_write(E+0x38,F(5));self.u.mem_write(E+0x3c,F(0.5))
        self.call(0x95d60,E)

    def snapshot(self):
        self.call(0x95dd8,E)
        values=struct.unpack('<'+'f'*(self.draw_count*6),self.u.mem_read(VERTICES,self.draw_count*24))
        return {'phase':struct.unpack('<f',self.u.mem_read(E+0x2c,4))[0],
                'draw_count':self.draw_count,'vertices':[list(values[i:i+6]) for i in range(0,len(values),6)],'color':self.colors[0]}

if __name__=='__main__':
    probe=WaterProbe();probe.setup()
    table={'permutation':list(struct.unpack('<1026I',probe.u.mem_read(PERLIN+12,4104))),
           'gradients':list(struct.unpack('<1026f',probe.u.mem_read(PERLIN+0x2014,4104)))}
    samples=[]
    for value in [-5.125,-1,0,0.1,0.25,0.7,1,13.999,1024.5]:
        probe.call(0x114928,PERLIN,BITS(value));samples.append({'x':value,'noise':struct.unpack('<f',I(probe.u.reg_read(UC_ARM_REG_R0)))[0]})
    cases=[]
    for dt in [0,333,1667,2000,8345.6]:
        probe.call(0x96264,E,BITS(dt));cases.append({'dt_ms':dt,**probe.snapshot()})
    configurations=[]
    for plane,segments,water_uv,mask_uv in [((1024,1024),(15,28),(0,1,0,1),(0,2,0,2)),((738,1024),(12,20),(0.1,0.9,0.2,0.8),(0.05,1.95,0.1,1.9))]:
        alternate=WaterProbe();alternate.setup(plane,segments,water_uv,mask_uv);frames=[]
        for dt in [0,333,1667,2000,8345.6]:
            alternate.call(0x96264,E,BITS(dt));frames.append({'dt_ms':dt,**alternate.snapshot()})
        configurations.append({'plane':plane,'segments':segments,'water_uv':water_uv,'mask_uv':mask_uv,'cases':frames})
    texture_uv_samples=[]
    for size,origin,frame in [((512,512),(0,0),(512,512)),((256,256),(0,0),(512,512)),((512,256),(12,24),(100,50))]:
        probe.u.mem_write(E,I(0)+I(E+0x1000)+I(frame[0])+I(frame[1])+bytes(100))
        probe.u.mem_write(E+0x2c,struct.pack('<2I',*origin))
        probe.u.mem_write(E+0x1010,struct.pack('<2I',size[1],size[0]))
        probe.call(0x1260f8,E)
        texture_uv_samples.append({'size':size,'origin':origin,'frame':frame,'uv':struct.unpack('<4f',probe.u.mem_read(E+0x44,16))})
    result={'original_sha256':EXPECTED_SHA,'method':__doc__,'rand_source':'https://github.com/apple-oss-distributions/Libc/blob/Libc-825.25/stdlib/FreeBSD/rand.c',
            'seed':probe.seed,'random_values':probe.random_values,'table':table,'noise_samples':samples,'plane':[1024,1024],'segments':[15,28],
            'water_uv':[0,1,0,1],'mask_uv':[0,1,0,1],'density':5,'mask_scale':0.5,'amplitude':0.18,'speed':4000,'cases':cases,
            'configurations':configurations,'texture_uv_samples':texture_uv_samples}
    Path('tests/fixtures/native-water-reference.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'cases':len(cases),'vertices':sum(c['draw_count'] for c in cases),'seed':probe.seed,'random_calls':len(probe.random_values),'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}))
