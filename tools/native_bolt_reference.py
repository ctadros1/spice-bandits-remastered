"""Bounded original CBolt::FillBuffer geometry, UV and color execution.

No game/rendering/RNG execution. Explicit segment records and stack arguments
exercise original math; each output vertex is copied from the ARM buffer.
"""
from native_creep_reference import *


def sample(points, width, intensity, alpha, pass_id):
    probe=Probe();u=probe.u
    obj=E;items=E+0x1000;buffer=E+0x3000;counter=E+0x4000
    u.mem_write(obj,bytes(128))
    count=len(points)-1
    u.mem_write(obj+0x18,I(items));u.mem_write(obj+0x1c,I(items+count*4))
    for i in range(count):
        data=E+0x2000+i*32
        u.mem_write(items+i*4,I(data));u.mem_write(data,struct.pack('<4f',*points[i],*points[i+1]))
    u.mem_write(counter,I(0))
    for index in range(count-1):
        sp=STACK-32
        u.mem_write(sp,struct.pack('<4I',BITS(width[index]),intensity,alpha,pass_id))
        for reg,value in [(UC_ARM_REG_SP,sp),(UC_ARM_REG_LR,END|1),(UC_ARM_REG_R0,obj),(UC_ARM_REG_R1,index),(UC_ARM_REG_R2,buffer),(UC_ARM_REG_R3,counter)]:u.reg_write(reg,value)
        u.emu_start(0xdd749,END,count=10000)
    n=struct.unpack('<I',u.mem_read(counter,4))[0]
    vertices=[]
    for i in range(n):
        value=struct.unpack('<2f2H4B',u.mem_read(buffer+i*16,16))
        vertices.append({'pos':value[:2],'uv':value[2:4],'color':value[4:]})
    return vertices


if __name__=='__main__':
    cases=[]
    for points in [[(i*20,0) for i in range(7)],[(0,0),(20,5),(40,-7),(60,8),(80,2),(100,-6),(120,0)],[(0,0),(2,5),(3,-3),(7,8),(9,2),(10,-6),(12,0)]]:
        for alpha in [255,128]:
            for pass_id in [1,2]:
                widths=[int(((6+1-i)*(12 if pass_id==1 else 24))/5) for i in range(5)]
                intensity=255 if pass_id==1 else int(alpha*.25)
                cases.append({'points':points,'widths':widths,'pass':pass_id,'intensity':intensity,'alpha':alpha if pass_id==1 else intensity,'vertices':sample(points,widths,intensity,alpha if pass_id==1 else intensity,pass_id)})
    result={'original_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'method':'CBolt::FillBuffer0xdd748 only. Explicit original segment records; no renderer, original global RNG or whole-game execution. Vector2Normalize original instructions run without a stub.','cases':cases}
    Path('tests/fixtures/native-bolt-reference.json').write_text(json.dumps(result,indent=2)+'\n')
    print(len(cases),'native bolt cases',len(cases[0]['vertices']),'vertices')
