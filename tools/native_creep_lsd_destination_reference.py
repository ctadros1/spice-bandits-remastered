"""R158 full original Disco destination selection, count and RNG helpers.
GetCreepLsdPos132/CountWalkableCells56/Rand8/RandFunction24 execute on supplied
ordered cell-pointer vectors, flag/affiliation/coordinate fields and actor seed.
Only the external unsigned remainder helper is stubbed with r0%r1; all cases
have at least one eligible cell. Full pathfinder/route attempts, map parser,
room/spawn/caller ordering, constructor, rendering/GPU and game do not run.
"""
from native_creep_reference import *
MAP=E+0x1000;GRID=E+0x2000;VECTOR=E+0x3000;CELLS=E+0x4000;OUTPUT=E+0x10000
class Destination(Probe):
 def __init__(self):
  super().__init__();self.bodies={a:bytes(self.u.mem_read(a,n)) for a,n in [(0x1035c8,132),(0x103590,56),(0x110c30,8),(0x110c38,24)]};self.remainders=[]
 def hook(self,u,a,size,data):
  if a==0x36cadc:
   x=u.reg_read(UC_ARM_REG_R0);y=u.reg_read(UC_ARM_REG_R1);assert y>0;self.remainders.append({'numerator':x,'divisor':y,'result':x%y});self.ret(x%y);return
  super().hook(u,a,size,data)
 def prepare_cells(self,rows,seed):
  u=self.u;u.mem_write(E,bytes(0x20000));u.mem_write(MAP+0x74,I(GRID));u.mem_write(GRID+0xc,struct.pack('<2I',VECTOR,VECTOR+len(rows)*4));u.mem_write(E+0x13c,I(seed))
  for i,row in enumerate(rows):
   ptr=CELLS+i*0x200;u.mem_write(VECTOR+i*4,I(ptr));u.mem_write(ptr+8,struct.pack('<2i',row['x'],row['y']));u.mem_write(ptr+0x18,bytes([row['flags']]));u.mem_write(ptr+0x108,I(row['affiliation']))
 def choose(self,player):
  self.remainders=[];u=self.u;sp=STACK-0x1000;u.mem_write(sp,I(player));u.mem_write(OUTPUT,struct.pack('<2i',-99,-101));u.reg_write(UC_ARM_REG_SP,sp);u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[MAP,OUTPUT,OUTPUT+4,E]):u.reg_write(reg,v)
  u.emu_start(0x1035c9,END,count=20000);assert u.reg_read(UC_ARM_REG_PC)==END
  assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  return {'destination':list(struct.unpack('<2i',u.mem_read(OUTPUT,8))),'seed':struct.unpack('<I',u.mem_read(E+0x13c,4))[0],'remainder':self.remainders.copy()}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-lsd-destination-reference.json');args=parser.parse_args();p=Destination();cases=[]
 patterns=[[(0,1)],[(0,1),(0,1),(0,1),(0,1)],[(0,1),(1,1),(2,1),(3,1),(0,0),(0,2),(0,3)],[(1,0),(2,0),(0,1),(1,3),(2,3),(3,3)]]
 for player in [1,2]:
  for pattern in patterns:
   for reverse in [False,True]:
    rows=[{'x':i*2+1,'y':i-3,'affiliation':a,'flags':f} for i,(a,f) in enumerate(pattern)]
    if reverse:rows.reverse()
    for seed in [0,1,2,65536,0x7fffffff,0xffffffff,0x12345678]:
     p.prepare_cells(rows,seed);frames=[p.choose(player) for _ in range(16)];eligible=[x for x in rows if x['affiliation'] in [0,player] and x['flags']&1];assert eligible
     prior=seed
     for frame in frames:
      prior=(prior*214013+2531011)&0xffffffff;ordinal=((prior>>16)&0x7fff)%len(eligible);selected=eligible[ordinal-1]
      assert frame['seed']==prior and frame['destination']==[selected['x'],selected['y']]
     cases.append({'player':player,'initial_seed':seed,'cells':rows,'reverse':reverse,'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_body_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'original_unchanged':True,'cases':cases};path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'selections':sum(len(c['frames']) for c in cases),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
