"""Original CMap::BoundOffset with explicit full lobby-map bounds.

Only the original bound arithmetic executes. Map bounds, zoom, viewport and
zero lobby top/bottom/minimum-cell offsets are explicit inputs. No map loader,
touch inertia, offset-lock animation, global scene or original pixels execute.
"""
from native_creep_reference import *

class CameraProbe(Probe):
    def sample(self,zoom,origin,size):
        self.u.mem_write(E,bytes(0x2000))
        for offset,value in [(0x130,int(4096*zoom)),(0x134,int(3072*zoom)),(0x140,4096),(0x144,3072),(0x148,4096),(0x14c,3072)]:self.u.mem_write(E+offset,I(value))
        self.u.mem_write(E+0x19c,F(zoom));self.point(E+0x1000,origin)
        self.u.mem_write(0x40a20c,I(MEMORY+80000));self.u.mem_write(0x40a204,I(MEMORY+80004));self.u.mem_write(MEMORY+80000,I(size[0])+I(size[1]))
        self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.mem_write(STACK-64,I(1)+I(1))
        self.u.reg_write(UC_ARM_REG_LR,END|1)
        for r,v in zip((UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3),(E,E+0x1000,0,BITS(1))):self.u.reg_write(r,v)
        self.u.emu_start(0x1081d9,END,count=10000);assert self.u.reg_read(UC_ARM_REG_PC)==END
        return list(struct.unpack('<2f',self.u.mem_read(E+0x1000,8)))

p=CameraProbe();cases=[]
for zoom in (0.2,0.25,0.289664379736688,0.625,1,1.2):
    for size in ((1024,768),(1280,960)):
        for x in (-5000,-1000,-0.5,0,1,280,5000):
            for y in (-5000,-1300,-0.5,0,1,75,5000):cases.append({'zoom':zoom,'origin':[x,y],'size':size,'result':p.sample(zoom,(x,y),size)})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-world-camera-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':record['original_unchanged']}))
