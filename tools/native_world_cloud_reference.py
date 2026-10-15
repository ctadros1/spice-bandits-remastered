"""Original lobby cloud generator setup and per-system overrides.

Original AddClouds and ProduceCloud math/branches execute. Allocations,
particle creation/emission, vector insertion and random helpers are explicit
stubs. Captures generator records, emitter coordinates, emission duration,
system-clock multiplier and color overrides, not complete clouds or pixels.
"""
from native_creep_reference import *


class CloudProbe(Probe):
    def hook(self,u,address,size,data):
        if address==0x8b590 and getattr(self,'capture_production',False):
            self.productions.append({'initial':u.reg_read(UC_ARM_REG_R1),'color_override':bool(u.mem_read(E+0x20,1)[0]),'gain':struct.unpack('<f',u.mem_read(E+0x24,4))[0]})
            u.mem_write(E+0x10,F(0));self.ret(0);return
        if address==0x111088 and getattr(self,'capture_production',False):
            self.particle_steps.append(struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R1)))[0]);self.ret();return
        if address in (0x110f0c,0x36c18c) and getattr(self,'capture_production',False):self.ret();return
        if address==0x36c6bc and getattr(self,'capture_production',False):
            target,source,count=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)]
            u.mem_write(target,bytes(u.mem_read(source,count)));self.ret(target);return
        if address==0x8b82c and getattr(self,'capture_visibility',False):
            self.visible_generators.append((u.reg_read(UC_ARM_REG_R0)-E-0x1000)//0x100);self.ret();return
        if address==0x8b9c8:self.ret();return
        if address in (0x36ca7c,):self.ret(0);return
        if address==0x36c1bc:
            pointer=E+0x1000+len(self.generators)*0x100
            self.ret(pointer);return
        if address==0x8b468:
            pointer=u.reg_read(UC_ARM_REG_R0);point=u.reg_read(UC_ARM_REG_R1)
            x,y=struct.unpack('<2f',u.mem_read(point,8));sp=u.reg_read(UC_ARM_REG_SP)
            radius=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R2)))[0]
            lifetime=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R3)))[0]
            rate,capacity=struct.unpack('<fI',u.mem_read(sp,8))
            self.generators.append({'position':[x,y],'radius':radius,'lifetime_ms':lifetime,'rate':rate,'capacity':capacity,'pointer':pointer})
            self.ret(pointer);return
        if address==0x91528:
            pointer=struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_R1),4))[0]
            self.u.mem_write(E+0x4000+len(self.inserted)*4,I(pointer));self.inserted.append(pointer)
            self.u.mem_write(E+0x80,I(E+0x4000)+I(E+0x4000+len(self.inserted)*4))
            self.ret();return
        if address==0x111834:
            self.ret(E+0x2000);return
        if address==0x110ab4:
            self.point(u.reg_read(UC_ARM_REG_R0),self.direction);self.ret();return
        if address==0x36c7cc:self.ret(self.random_radius);return
        if address==0x36cadc:
            self.ret(u.reg_read(UC_ARM_REG_R0)%u.reg_read(UC_ARM_REG_R1));return
        if address==0x110a78:self.ret(BITS(self.clock_ratio));return
        if address==0x111418:self.emit_calls+=1;self.ret(1);return
        if address==0x81bb0:self.ret();return
        super().hook(u,address,size,data)

    def invoke(self,address,args,stack=b''):
        self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
        if stack:self.u.mem_write(STACK-64,stack)
        for r,v in zip((UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3),args):self.u.reg_write(r,v)
        self.u.emu_start(address|1,END,count=100000)
        assert self.u.reg_read(UC_ARM_REG_PC)==END

    def setup(self):
        self.u.mem_write(E,bytes(0x6000));self.generators=[];self.inserted=[]
        self.invoke(0x8e610,[E])
        for g in self.generators:
            pointer=g.pop('pointer');g['color_override']=bool(self.u.mem_read(pointer+0x20,1)[0])
            g['color_gain']=struct.unpack('<f',self.u.mem_read(pointer+0x24,4))[0] if g['color_override'] else 1.0
        return self.generators

    def produce(self,g,direction,radial,ratio,initial):
        self.u.mem_write(E,bytes(0x4000));system=E+0x2000
        self.u.mem_write(E, F(g['position'][0])+F(g['position'][1])+F(g['radius']))
        self.u.mem_write(E+0x10,F(90)+F(g['lifetime_ms']))
        self.u.mem_write(E+0x20,bytes([g['color_override']]))
        self.u.mem_write(E+0x24,F(g['color_gain']))
        self.u.mem_write(system+0x38,F(0.5)*4)
        self.direction=direction;self.random_radius=radial;self.clock_ratio=ratio;self.emit_calls=0
        self.invoke(0x8b590,[E,initial])
        return {'position':list(struct.unpack('<2f',self.u.mem_read(system+0xa0,8))),
                'color':list(struct.unpack('<4f',self.u.mem_read(system+0x38,16))),
                'emission_seconds':struct.unpack('<f',self.u.mem_read(system+0x4c,4))[0],
                'clock_ratio':struct.unpack('<f',self.u.mem_read(system+0x50,4))[0],
                'initial_emits':self.emit_calls,'generator_spawn_timer':struct.unpack('<f',self.u.mem_read(E+0x10,4))[0]}

    def visibility(self,generators,zoom,origin,size):
        self.capture_visibility=True
        self.u.mem_write(E,bytes(0x8000));self.visible_generators=[]
        self.u.mem_write(E+0x20,I(E+0x7000));self.u.mem_write(E+0x60,F(16.67))
        self.u.mem_write(E+0x80,I(E+0x4000)+I(E+0x4000+len(generators)*4))
        self.u.mem_write(E+0x7128,F(origin[0])+F(origin[1]))
        self.u.mem_write(E+0x719c,F(zoom))
        self.u.mem_write(0x40a20c,I(MEMORY+80000));self.u.mem_write(0x40a204,I(MEMORY+80004))
        self.u.mem_write(MEMORY+80000,I(size[0])+I(size[1]))
        for i,g in enumerate(generators):
            pointer=E+0x1000+i*0x100
            self.u.mem_write(E+0x4000+i*4,I(pointer))
            self.u.mem_write(pointer,F(g['position'][0])+F(g['position'][1])+F(g['radius']))
        self.invoke(0x90350,[E]);self.capture_visibility=False;return self.visible_generators

    def constructor(self,g):
        self.u.mem_write(E,bytes(0x8000));self.point(E+0x6000,g['position'])
        self.capture_production=True;self.productions=[]
        self.invoke(0x8b48c,[E,E+0x6000,BITS(g['radius']),BITS(g['lifetime_ms'])],F(g['rate'])+I(g['capacity']))
        self.capture_production=False
        return {'initial_productions':self.productions,'particle_dt_per_ms':struct.unpack('<f',self.u.mem_read(E+0x1c,4))[0]}

    def update(self,g,count,steps,expired=-1):
        self.u.mem_write(E,bytes(0x16000));self.capture_production=True;self.productions=[];self.particle_steps=[]
        self.u.mem_write(E+0x18,I(g['capacity'])+F(g['rate']*0.001))
        self.u.mem_write(E+0x28,I(E+0x4000)+I(E+0x4000+count*4))
        for i in range(count):
            pointer=E+0x8000+i*0x100
            self.u.mem_write(E+0x4000+i*4,I(pointer));self.u.mem_write(pointer+0xb8,I(1))
            if i==expired:self.u.mem_write(pointer+0xb8,I(0));self.u.mem_write(pointer+0x4c,F(4))
        frames=[]
        for dt in steps:
            self.productions=[];self.particle_steps=[];self.invoke(0x8b82c,[E,BITS(dt)])
            frames.append({'dt_ms':dt,'productions':self.productions,'particle_steps':self.particle_steps,
                           'remaining_systems':(struct.unpack('<I',self.u.mem_read(E+0x2c,4))[0]-(E+0x4000))//4,
                           'spawn_timer':struct.unpack('<f',self.u.mem_read(E+0x10,4))[0]})
        self.capture_production=False;return frames


p=CloudProbe();generators=p.setup();cases=[]
for g in generators:
    for direction,radial,ratio in [((1,0),0,0.7),((0,-1),int(g['radius'])-1,1),((-0.6,0.8),53,0.85)]:
        for initial in (0,1):
            cases.append({'generator':g,'direction':direction,'random_radius':radial,'clock_ratio':ratio,
                          'initial':initial,'result':p.produce(g,direction,radial,ratio,initial)})
visibility=[{'zoom':zoom,'origin':origin,'size':size,'visible':p.visibility(generators,zoom,origin,size)}
            for zoom in (0.2,0.625,1) for origin in ((0,0),(-300,-1100),(-5000,0),(1000,1000))
            for size in ((1024,768),(1280,960))]
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'generators':generators,'cases':cases,'visibility':visibility,
        'constructors':[{'generator':g,'result':p.constructor(g)} for g in generators],
        'updates':[{'generator':generators[0],'count':count,'frames':p.update(generators[0],count,[0,16.67,30,33.33,80,500])} for count in (0,1,49,50)],
        'expiry':[{'generator':generators[0],'count':count,'frames':p.update(generators[0],count,[80,0],0)} for count in (1,50)],
        'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-world-cloud-reference.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'generators':len(generators),'produce_cases':len(cases),'visibility_cases':len(visibility),'original_unchanged':record['original_unchanged']}))
