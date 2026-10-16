"""Full original ProcessPlayers and FreezeCreeps/UseFreeze supplied records.
One/two player vectors, resources/countdowns and creep owner/state records are
supplied. Sounds/statistics/LSD callbacks are recording stubs. No room clock
producer, constructor, spawn, profile service, whole scene or GPU executes.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_owner_reference import *
class Freeze(OwnerProbe):
 def hook(self,u,a,size,data):
  if a in [0xc9620,0xfc0a0,0xff0d4]:self.ret();return
  if a==0x1206e4:self.sounds.append(self.string(u.reg_read(UC_ARM_REG_R0)));self.ret();return
  super().hook(u,a,size,data)
 def players(self,remaining,dt):
  self.reset();self.sounds=[];room=E+0x8000;vector=E+0x5000;begin=E+0x6000
  self.u.mem_write(0x40a124,I(vector));self.u.mem_write(vector,struct.pack('<2I',begin,begin+4*len(remaining)))
  for i,count in enumerate(remaining):
   player=E+0x7000+i*0x100;self.u.mem_write(begin+i*4,I(player));self.u.mem_write(player+0x30,struct.pack('<i',count))
  self.u.mem_write(room+0x24d,b'\x01');self.invoke(0xd4080,[room,BITS(dt)])
  return {'remaining':[struct.unpack('<i',self.u.mem_read(E+0x7030+i*0x100,4))[0] for i in range(len(remaining))],'room_active':bool(self.u.mem_read(room+0x24d,1)[0]),'sounds':list(self.sounds)}
 def attach(self,player_owner,count,owners,states):
  self.reset();player=E+0x7000;begin=E+0x6000;self.u.mem_write(player+4,I(player_owner));self.u.mem_write(player+0x30,struct.pack('<i',count));self.u.mem_write(0x47ed54,struct.pack('<2I',begin,begin+4*len(owners)))
  for i,(owner,state) in enumerate(zip(owners,states)):
   actor=E+0x10000+i*0x1000;self.u.mem_write(actor,bytes(0x1000));self.u.mem_write(begin+i*4,I(actor));self.u.mem_write(actor+0x160,I(owner));self.u.mem_write(actor+0x170,bytes([state]));self.u.mem_write(actor+0x2d8,I(actor+0x500));self.u.mem_write(actor+0x504,I(17))
  self.invoke(0xfbddc,[player])
  return [{'attached':struct.unpack('<I',self.u.mem_read(E+0x10000+i*0x1000+0x20c,4))[0]==player+0x30,'tracker':struct.unpack('<I',self.u.mem_read(E+0x10000+i*0x1000+0x504,4))[0]} for i in range(len(owners))]
def main():
 p=Freeze();timers=[];attachments=[]
 for remaining in [[],[0],[-1],[1],[16],[17],[30],[10000],[0,100],[30,1],[1,0],[100,100]]:
  for dt in [0,.1,16.667,30,31,10001]:timers.append({'input':dict(remaining=remaining,dt=dt),'output':p.players(remaining,dt)})
 for owner in [0,1,2]:
  for count in [0,1,10000]:
   for rotation in range(8):
    owners=[0,1,2,0,1,2,0,2];states=[(i+rotation)%8 for i in range(8)];inp=dict(player_owner=owner,count=count,owners=owners,states=states);attachments.append({'input':inp,'output':p.attach(**inp)})
 data={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'timers':timers,'attachments':attachments};Path('tests/fixtures/native-creep-freeze-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'timers':len(timers),'attachments':len(attachments),'creeps':sum(len(c['output']) for c in attachments),'original_unchanged':data['original_unchanged']}))
if __name__=='__main__':main()
