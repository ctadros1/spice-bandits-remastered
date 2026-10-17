"""R155 complete original Disco admission/expiry field probe.
Full Creep.UseLsd172/ProcessLsd92/SetState112 and static manager52/40 bodies
execute on supplied actor/player/cell/vector records. GetCell, displacement
release, path recomputation and hover helper are recording stubs. No constructor,
original timer producer, movement/pathfinder, particle emission, room/GPU/game.
Raw fields are named by offsets unless independently established elsewhere.
"""
import json,struct,hashlib,itertools,argparse
from pathlib import Path
from native_creep_reference import *
PLAYER=E+0x8000;MAP=E+0x9000;GRID=E+0xa000;CELL=E+0xb000;VECTOR=E+0xc000;OLD=E+0xd000;GLOBAL=0x47ed54
class Lsd(Probe):
 def __init__(self):
  super().__init__();self.calls=[];self.cells={};self.body={a:bytes(self.u.mem_read(a,size)) for a,size in [(0x7bb14,172),(0x7bbc0,92),(0x798ec,112),(0xfc06c,52),(0xfc0a0,40)]}
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==0x1066fc:
   self.calls.append({'call':'GetCell-stub','x':r1,'y':r2});value=self.cells.get(r1)
   if value is None:self.ret(0)
   else:p=CELL+r1*0x200;u.mem_write(p+0x108,struct.pack('<i',value));self.ret(p)
   return
  if a==0x10b904:
   self.calls.append({'call':'FreeDisplace-stub','x':r1,'y':r2,'slot':r3});self.ret();return
  if a==0x7ace0:self.calls.append({'call':'UpdateShortestPath-stub','actor':(r0-E)//0x1000,'argument':r1});self.ret();return
  if a==0x7e870:self.calls.append({'call':'Hover-stub','actor':(r0-E)//0x1000});self.ret();return
  if a==0x798ec:self.calls.append({'call':'SetState-full','actor':(r0-E)//0x1000,'state':r1})
  if a==0x7bb14:self.calls.append({'call':'UseLsd-full','actor':(r0-E)//0x1000})
  super().hook(u,a,size,data)
 def invoke(self,address,args):
  self.calls=[];self.stop=END;self.u.reg_write(UC_ARM_REG_SP,STACK-0x1000);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],args):self.u.reg_write(reg,v)
  self.u.emu_start(address|1,END,count=20000);assert self.u.reg_read(UC_ARM_REG_PC)==END
  assert all(bytes(self.u.mem_read(a,len(b)))==b for a,b in self.body.items())
 def prepare(self,rows,player=1):
  self.u.mem_write(E,bytes(0x18000));self.cells={};self.u.mem_write(PLAYER+4,I(player));self.u.mem_write(PLAYER+0x38,I(100));self.u.mem_write(OLD,I(50));self.u.mem_write(MAP+0x74,I(GRID));self.u.mem_write(GLOBAL,struct.pack('<2I',VECTOR,VECTOR+len(rows)*4))
  for i,row in enumerate(rows):
   a=E+i*0x1000;ps=E+0x10000+i*0x100;x=6+i;self.cells[x]=row['cell'];self.u.mem_write(VECTOR+i*4,I(a))
   self.u.mem_write(a+0x1c,I(MAP));self.u.mem_write(a+0x40,I(23));self.u.mem_write(a+0x44,I(47));self.u.mem_write(a+0x138,I(17));self.u.mem_write(a+0x148,struct.pack('<2i',x,7));self.u.mem_write(a+0x160,I(row.get('owner',0)));self.u.mem_write(a+0x170,bytes([row['state'],row['previous']]));self.u.mem_write(a+0x174,I(13));self.u.mem_write(a+0x210,I(OLD if row['existing'] else 0));self.u.mem_write(a+0x214,bytes([int(row['flag214'])]));self.u.mem_write(a+0x236,b'\x01');self.u.mem_write(a+0x25f,b'\x01');self.u.mem_write(a+0x2d4,I(ps if row['slot'] else 0));self.u.mem_write(ps+4,I(17))
 def snapshot(self,i=0):
  a=E+i*0x1000;word=lambda off:struct.unpack('<I',self.u.mem_read(a+off,4))[0];ptr=word(0x210)
  return {'state':self.u.mem_read(a+0x170,1)[0],'previous':self.u.mem_read(a+0x171,1)[0],'field40':word(0x40),'field44':word(0x44),'field174':word(0x174),'timer_pointer':'player+0x38' if ptr==PLAYER+0x38 else 'old' if ptr==OLD else hex(ptr),'flag214':self.u.mem_read(a+0x214,1)[0],'flag236':self.u.mem_read(a+0x236,1)[0],'flag25f':self.u.mem_read(a+0x25f,1)[0],'rate':struct.unpack('<I',self.u.mem_read(word(0x2d4)+4,4))[0] if word(0x2d4) else None}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-lsd-reference.json');args=parser.parse_args()
 p=Lsd();cases=[]
 for state,player,cell,flag,slot,existing,previous in itertools.product(range(8),[1,2],[None,0,1,2,3],[False,True],[False,True],[False,True],[0,4]):
  inp={'state':state,'player':player,'cell':cell,'flag214':flag,'slot':slot,'existing':existing,'previous':previous};p.prepare([inp],player);before=p.snapshot();p.invoke(0x7bb14,[E,PLAYER]);after=p.snapshot();usecalls=p.calls.copy();frames=[]
  for count in [100,1,0,-1]:
   p.u.mem_write(PLAYER+0x38,struct.pack('<i',count));p.invoke(0x7bbc0,[E]);frames.append({'supplied_player_counter':count,'after':p.snapshot(),'calls':p.calls.copy()})
  cases.append({'input':inp,'before':before,'after_use':after,'use_calls':usecalls,'frames':frames})
 managers=[]
 for player in [1,2]:
  for cell in [0,1,2,None]:
   rows=[{'state':s,'owner':o,'cell':cell,'flag214':False,'slot':True,'existing':False,'previous':4} for s,o in [(0,0),(0,1),(4,2),(7,1)]];p.prepare(rows,player);p.invoke(0xfc06c,[PLAYER]);after=[p.snapshot(i) for i in range(4)];calls=p.calls.copy()
   for i in range(4):p.u.mem_write(E+i*0x1000+0x214,b'\x01')
   p.invoke(0xfc0a0,[]);managers.append({'player':player,'rows':rows,'after_use':after,'use_calls':calls,'after_reset':[p.snapshot(i) for i in range(4)]})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_body_bytes':{hex(a):len(b) for a,b in p.body.items()},'original_unchanged':True,'cases':cases,'manager_sequences':managers}
 assert len(cases)==1280 and len(managers)==8
 path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'manager_sequences':len(managers),'fixture_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
