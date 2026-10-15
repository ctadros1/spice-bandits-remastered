"""Full original CheckForTransfer on supplied creep vector/list/position records.

Sound, list insertion/removal/allocation and TeleportCreep are explicit stubs.
List link mutation is supplied so subsequent original queue reads execute.
Original eligibility, half-cell entry, markers and call order execute. This
does not execute movement, pathfinding, TeleportCreep, room or rendering.
"""
import sys
sys.path.insert(0,'tools')
from native_map_order_reference import *
class Transfer(OrderProbe):
 def hook(self,u,a,size,data):
  r0,r1,r2=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a==0x1206e4:self.calls.append({'method':'sound','name':self.string(r0)});self.ret();return
  if a==0x9d528:
   actor=struct.unpack('<I',u.mem_read(r2,4))[0];sentinel=r0;previous=struct.unpack('<I',u.mem_read(sentinel+4,4))[0];node=E+0xb000+16*self.nodes;self.nodes+=1
   u.mem_write(node,I(sentinel)+I(previous)+I(actor));u.mem_write(previous,I(node));u.mem_write(sentinel+4,I(node));self.calls.append({'method':'queue','actor':actor-E});self.ret();return
  if a==0x36c08c:
   after,before=struct.unpack('<2I',u.mem_read(r0,8));u.mem_write(before,I(after));u.mem_write(after+4,I(before));self.calls.append({'method':'unhook','node':r0-E});self.ret();return
  if a==0x36c18c:self.calls.append({'method':'delete-node','node':r0-E});self.ret();return
  if a==0x9c2c8:self.calls.append({'method':'teleport','actor':r1-E});self.ret();return
  super().hook(u,a,size,data)
 def state(self):
  actor=E+0x1000
  queue=[];node=struct.unpack('<I',self.u.mem_read(E+0x80,4))[0]
  while node!=E+0x80:
   after,before,value=struct.unpack('<3I',self.u.mem_read(node,12));queue.append(value-E);node=after;assert len(queue)<10
  return {'portal_state':struct.unpack('<I',self.u.mem_read(actor+0x354,4))[0],'clock':struct.unpack('<f',self.u.mem_read(actor+0x350,4))[0],'marker':list(struct.unpack('<2i',self.u.mem_read(actor+0x168,8))),'queue':queue,'calls':list(self.calls)}
 def setup_case(self,kind,state,phase,progress,target,previous,marker,resource_type=1):
  self.reset();self.calls=[];self.nodes=0;actor=E+0x1000
  self.u.mem_write(E+0x44,I(7)+I(4));self.u.mem_write(E+0x68,I(kind));self.u.mem_write(E+0x7c,I(E+0xa000));self.u.mem_write(E+0x80,I(E+0x80)+I(E+0x80))
  vector=struct.unpack('<I',self.u.mem_read(0x40a11c,4))[0];self.u.mem_write(vector,I(E+0x9000)+I(E+0x9004)+I(E+0x9100));self.u.mem_write(E+0x9000,I(actor))
  self.u.mem_write(actor+0x250,I(E+0x8000));self.u.mem_write(E+0x8004,I(resource_type));self.u.mem_write(actor+0x170,bytes([state]));self.u.mem_write(actor+0x354,I(phase));self.u.mem_write(actor+0x350,F(27))
  self.u.mem_write(actor+0x158,F(progress));self.u.mem_write(actor+0x150,struct.pack('<2i',*target));self.u.mem_write(actor+0x148,struct.pack('<2i',*previous));self.u.mem_write(actor+0x168,struct.pack('<2i',*marker))
 def call(self):
  self.calls=[];self.invoke(0x9c16c,[E]);return {'return':self.u.reg_read(UC_ARM_REG_R0),'output':self.state()}
def main():
 p=Transfer();cases=[]
 for resource_type in [1,2]:
  for kind in [0,1]:
   for state in range(7):
    for phase in [0,1,2,3]:
     for progress in [0,.499999,.5,.999999,1]:
      p.setup_case(kind,state,phase,progress,[7,4],[6,4],[-1,-1],resource_type);cases.append({'kind':kind,'creep_state':state,'portal_state':phase,'progress':progress,'resource_type':resource_type,**p.call()})
 p.setup_case(0,0,0,.5,[7,4],[6,4],[-1,-1]);sequence=[p.call()]
 p.u.mem_write(E+0x1000+0x148,I(7)+I(4));p.u.mem_write(E+0x1000+0x150,I(8)+I(4));sequence.append(p.call())
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'half_cell_sequence':sequence,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-portal-transfer-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sequence':sequence,'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
