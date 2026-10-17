"""R159 original constructor + Disco activation/player timer/owner/PS.
Full original constructor/factory/PS.C2/SetState, ActiveLsd/GetLsdDuration,
UseLsd/ProcessPlayers/ProcessLsd/SetCanUseLsd, Creep.Update/ProcessSpeed/
ProcessFreeze/UpdateParticles and Particle.Update/Emit execute on selected
R149 headers with R150 time_scale1/texture-count1/zero velocity variation.
The original initialized heavy-disable byte1 is asserted and retained.
Room/player/vector/base duration600/upgrade0 and GetCell neutral supplied.
Movement/fly/portal/grow/bubble/hover/path/resource/map/string/texture/new,
upgrade lookup/percentage/audio/random0/vector0/trig are explicit stubs.
No actual room UpdateGame/ProcessWaves/pathfinder/death/game/GPU executes.
"""
import sys,math,json,struct,hashlib,argparse
sys.path.insert(0,'tools')
from native_creep_owner_birth_tail_reference import *
PLAYER=E+0xa0000;GRID=E+0xa1000;CELL=E+0xa2000;PVECTOR=E+0xa3000;PITEMS=E+0xa4000;CITEMS=E+0xa5000;BASE=E+0xa6000;PANEL=E+0xa7000
class DiscoEmission(FreezeEmission):
 def __init__(self):
  super().__init__();self.actions=[];assert self.word(0x40a1e8)==0x47c580 and bytes(self.u.mem_read(0x47c580,1))==b'\x01'
  for a in [0x98b6c,0xc02b8,0x7bb14,0xfc06c,0xd4080,0x7bbc0,0xfc0a0,0x7e8d0,0x7a924,0x7bc3c,0x7bce4,0x111088,0x111418]:self.bodies[a]=bytes(self.u.mem_read(a,next(r['size'] for r in self.catalog if r['address']==a)))
 def hook(self,u,a,size,data):
  if a==0x1066fc:self.ret(CELL);return
  if a in [0x7ace0,0x10b904,0xd8b00,0xc9620,0xff0d4,0x1206e4]:self.actions.append(hex(a));self.ret();return
  if a in [0x7fa18,0xd96d8]:self.ret(0 if a==0x7fa18 else 5);return
  super().hook(u,a,size,data)
 def sample_disco(self,name,dt):
  self.emits=[];ctor=self.sample(name);u=self.u;room=E+0x1000;map_obj=E+0x2000;u.mem_write(PLAYER,bytes(0x8000))
  nodes=[node for alias,node in sorted(self.slots.items())];self.owned_next={node:(nodes[i+1] if i+1<len(nodes) else E+0x268) for i,node in enumerate(nodes)};u.mem_write(E+0x270,I(nodes[0]));u.mem_write(E+0x3000+0x14,I(1000))
  for node in nodes:
   p=self.word(node+0x14);u.mem_write(p+0x50,F(1));u.mem_write(p+0x7c,I(1));u.mem_write(p+0x48,F(0));child=self.word(p+0x100);u.mem_write(child-12,bytes(12))
  u.mem_write(map_obj+0x74,I(GRID));u.mem_write(CELL+0x108,I(0));u.mem_write(PLAYER+4,I(1));u.mem_write(0x40a240,I(BASE));u.mem_write(BASE,I(600));u.mem_write(PANEL+4,I(room));u.mem_write(room+0x334,I(1));u.mem_write(room+0x2ac,I(1));u.mem_write(room+0x2a8,I(PLAYER));u.mem_write(0x40a124,I(PVECTOR));u.mem_write(PVECTOR,struct.pack('<2I',PITEMS,PITEMS+4));u.mem_write(PITEMS,I(PLAYER));u.mem_write(0x47ed54,struct.pack('<2I',CITEMS,CITEMS+4));u.mem_write(CITEMS,I(E))
  self.actions=[];self.invoke(0x98b6c,[PANEL,PLAYER]);activation=self.actions.copy();rows=[]
  for frame in range(181):
   if frame:
    self.actions=[];self.invoke(0xd4080,[room,BITS(dt)]);self.invoke(0x7e8d0,[E,BITS(dt),0])
   rows.append({'frame':frame,'state':u.mem_read(E+0x170,1)[0],'previous':u.mem_read(E+0x171,1)[0],'counter':self.word(PLAYER+0x38),'timer_attached':self.word(E+0x210)==PLAYER+0x38,'flag214':u.mem_read(E+0x214,1)[0],'actions':self.actions.copy(),'roots':[{'alias':alias,'active':self.word(self.word(node+0x14)+0xb8),'clock_bits':self.word(self.word(node+0x14)+0xc0),'release_bits':self.word(self.word(node+0x14)+0xc4),'rate':self.word(self.word(node+0x14)+4),'first_release':u.mem_read(self.word(node+0x14)+0xd6,1)[0],'active_birth_bits':self.born_chain(self.word(self.word(node+0x14)+0xdc)),'pool_size':len(self.born_chain(self.word(self.word(node+0x14)+0xe0)))} for alias,node in self.slots.items()]})
   assert all(bytes(u.mem_read(a,len(b)))==b for a,b in self.bodies.items())
  return {'resource':name,'delta':dt,'activation_actions':activation,'constructor':ctor,'frames':rows,'emits':self.emits}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',default='tests/fixtures/native-creep-disco-emission-reference.json');args=parser.parse_args()
 p=DiscoEmission();cases=[]
 for n in range(1,11):
  for dt in [16.667,30,100]:
   c=p.sample_disco('creeps/creep'+str(n),dt);lsd=lambda f:next(r for r in f['roots'] if r['alias']=='lsd');first=c['frames'][0];expiry=next(f for f in c['frames'] if f['counter']==0)
   assert first['state']==7 and first['counter']==600 and first['timer_attached'] and lsd(first)['rate']==1 and lsd(first)['active']==0 and lsd(first)['clock_bits']==0
   assert expiry['state']==0 and not expiry['timer_attached'] and lsd(expiry)['rate']==0
   assert lsd(c['frames'][-1])['active']==0
   if any(e['alias']=='lsd' and e['count']>0 for e in c['emits']):assert lsd(c['frames'][-1])['pool_size']>0
   assert all(len(root['active_birth_bits'])==root['active'] for f in c['frames'] for root in f['roots'])
   cases.append(c)
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'full_body_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'original_unchanged':True,'cases':cases};path=Path(args.output);path.write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['frames']) for c in cases),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
