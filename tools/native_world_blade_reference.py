"""Original lobby windmill vertex submissions and update arithmetic.

OpenGL and unrelated lobby/UI/map updates are stubs. Original fixed world
coordinates, texture-matrix angles, sheared quad generation and five angle
increments execute. Texture dimensions/offset/UV and initial angles/speeds
are explicit inputs; no original texture loader, RNG or rasterizer executes.
"""
from native_creep_reference import *


class BladeProbe(Probe):
    def hook(self, u, address, size, data):
        if address == 0x36b57c:
            self.angles.append(struct.unpack('<f', I(u.reg_read(UC_ARM_REG_R0)))[0])
            self.ret(); return
        if address == 0x36b63c:
            pointer = u.reg_read(UC_ARM_REG_R3)
            self.quads.append([list(struct.unpack('<4f', u.mem_read(pointer+i*16,16))) for i in range(4)])
            self.ret(); return
        if address in {0x36b52c,0x36b55c,0x36b50c,0x36b60c,0x36b3cc,0x11520c,
                       0x36b3dc,0x36b5cc,0x36b3bc,0x36b3ac,0x36b54c,0x36ca7c,
                       0x8fe64,0x8a2a8,0x109560,0x103d20,0x10a0e0}:
            self.ret(0); return
        super().hook(u,address,size,data)

    def invoke(self, address, dt=0):
        self.u.reg_write(UC_ARM_REG_SP,STACK-64)
        self.u.reg_write(UC_ARM_REG_LR,END|1)
        self.u.reg_write(UC_ARM_REG_R0,E)
        self.u.reg_write(UC_ARM_REG_R1,BITS(dt))
        self.u.emu_start(address|1,END,count=100000)
        assert self.u.reg_read(UC_ARM_REG_PC)==END

    def render(self,angles,offset):
        self.u.mem_write(E,bytes(0x5000)); texture=E+0x1000
        self.u.mem_write(E+0x8c,I(E+0x2000))
        self.u.mem_write(E+0xc8,I(texture))
        self.u.mem_write(texture+4,I(E+0x1800))
        self.u.mem_write(texture+8,I(32)+I(32))
        self.u.mem_write(texture+0x20,F(offset[0])+F(offset[1]))
        self.u.mem_write(texture+0x44,F(0)+F(1)+F(0)+F(1))
        self.u.mem_write(E+0x2000,b''.join(F(a) for a in angles))
        self.angles=[];self.quads=[]
        self.invoke(0x90cd8)
        return {'angles':self.angles,'quads':self.quads}

    def update(self,angles,speeds,steps):
        self.u.mem_write(E,bytes(0x5000))
        self.u.mem_write(E+0x1c,b'\x01');self.u.mem_write(E+0x5e,b'\x01')
        self.u.mem_write(E+0x20,I(E+0x1000)+I(0)+I(E+0x1100)+I(E+0x1200))
        self.u.mem_write(E+0x8c,I(E+0x2000));self.u.mem_write(E+0x98,I(E+0x2100))
        self.u.mem_write(E+0x2000,b''.join(F(a) for a in angles))
        self.u.mem_write(E+0x2100,b''.join(F(s) for s in speeds))
        result=[]
        for dt in steps:
            self.invoke(0x90428,dt)
            result.append({'dt_ms':dt,'angles':list(struct.unpack('<5f',self.u.mem_read(E+0x2000,20)))})
        return result


p=BladeProbe(); renders=[];updates=[]
for start in (0,45,90,180,270,359):
    angles=[start+i*13 for i in range(5)]
    for offset in ((0,0),(-16,-16)):
        renders.append({'initial_angles':angles,'offset':offset,'result':p.render(angles,offset)})
for speeds in ((0.7,0.8,0.9,1.0,1.4),(1.4,1.3,1.2,1.1,0.7)):
    angles=[0,45,90,180,359]
    updates.append({'initial_angles':angles,'speeds':speeds,
                    'frames':p.update(angles,speeds,[0,16.67,16.67,30,500,100000])})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'renders':renders,'updates':updates,
        'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-world-blade-reference.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'render_cases':len(renders),'quads':sum(len(c['result']['quads']) for c in renders),
                  'update_frames':sum(len(c['frames']) for c in updates),'original_unchanged':record['original_unchanged']}))
