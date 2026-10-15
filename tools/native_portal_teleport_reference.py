"""Full original TeleportCreep, SetState and GetFirstMovementPoint bridge.

UpdatePosition supplies an explicit two-node exit path (not pathfinding).
Map center, hover/sound and direction are supplied/recorded stubs. Actual
teleport position/aim/marker/phase writes and two path peek/pop calls execute.
"""
import sys
sys.path.insert(0,'tools')
from native_map_order_reference import *
class Teleport(OrderProbe):
 def hook(self,u,a,size,data):
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==0x7e870:self.calls.append({'method':'hover-state','state':r1});self.ret();return
  if a==0x7aaac:
   stack=u.reg_read(UC_ARM_REG_SP);self.calls.append({'method':'UpdatePosition','cells':[r1,r2,r3,struct.unpack('<I',u.mem_read(stack,4))[0]],'progress':struct.unpack('<f',u.mem_read(stack+4,4))[0]})
   actor=r0;u.mem_write(actor+0x148,I(self.exit_cell[0])+I(self.exit_cell[1])+I(self.exit_cell[0])+I(self.exit_cell[1]));u.mem_write(actor+0x158,F(0))
   u.mem_write(actor+0x40,I(E+0x7000)+I(E+0x7008)+I(E+0x7100));u.mem_write(E+0x7000,I(E+0x9000)+I(E+0x9100))
   for address,cell,point in [(E+0x9000,self.exit_cell,self.exit_point),(E+0x9100,self.next_cell,self.next_point)]:u.mem_write(address+8,I(cell[0])+I(cell[1]));self.point(address+0x10,point)
   self.ret();return
  if a==0x10b614:self.calls.append({'method':'hexcenter','cell':[r1,r2]});self.point(r3,self.exit_point);self.ret();return
  if a==0x7acac:self.calls.append({'method':'direction','force':r1});self.ret();return
  if a==0x7ba04:self.calls.append({'method':'GetFirstMovementPoint','pop':struct.unpack('<I',u.mem_read(u.reg_read(UC_ARM_REG_SP),4))[0]});return
  super().hook(u,a,size,data)
 def run(self,exit_cell,exit_point,next_cell,next_point,jitter,aim):
  self.reset();self.calls=[];self.exit_cell=exit_cell;self.exit_point=exit_point;self.next_cell=next_cell;self.next_point=next_point;actor=E+0x1000
  self.u.mem_write(E+0x7c,I(E+0x2000));self.u.mem_write(E+0x64,I(E+0x6000));self.u.mem_write(E+0x6074,I(E+0x6100));self.u.mem_write(E+0x2044,I(exit_cell[0])+I(exit_cell[1]))
  self.u.mem_write(actor+0x1c,I(E+0x6000));self.u.mem_write(actor+0x250,I(E+0x8000));self.u.mem_write(E+0x8034,I(0));self.u.mem_write(actor+0x170,b'\x04');self.u.mem_write(actor+0x350,F(171));self.u.mem_write(actor+0x354,I(3));self.point(actor+0x1c8,jitter);self.point(actor+0x54,aim)
  self.invoke(0x9c2c8,[E,actor]);point=lambda off:list(struct.unpack('<2f',self.u.mem_read(actor+off,8)))
  vector=struct.unpack('<2I',self.u.mem_read(actor+0x40,8))
  return {'state':self.u.mem_read(actor+0x170,1)[0],'portal_state':struct.unpack('<I',self.u.mem_read(actor+0x354,4))[0],'clock':struct.unpack('<f',self.u.mem_read(actor+0x350,4))[0],'logical':point(0x188),'movement_start':point(0x1a0),'drawn':point(0x4c),'aim':point(0x190),'marker':list(struct.unpack('<2i',self.u.mem_read(actor+0x168,8))),'cell':list(struct.unpack('<2i',self.u.mem_read(actor+0x150,8))),'next_point':point(0x180),'progress':struct.unpack('<f',self.u.mem_read(actor+0x158,4))[0],'position_enabled':bool(self.u.mem_read(actor+0x2a0,1)[0]),'remaining_path_nodes':(vector[1]-vector[0])//4,'calls':list(self.calls)}
def main():
 p=Teleport();cases=[]
 for cell,point,nextcell,nextpoint in [([12,9],[700,410],[13,9],[760,442]),([7,4],[231.25,150.875],[7,5],[231.25,214.875])]:
  for jitter in [[0,0],[2.75,-3.5]]:
   for aim in [[0,0],[5,-10]]:cases.append({'exit_cell':cell,'exit_point':point,'next_cell':nextcell,'next_point':nextpoint,'jitter':jitter,'aim_offset':aim,'output':p.run(cell,point,nextcell,nextpoint,jitter,aim)})
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-portal-teleport-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sample':cases[0],'original_unchanged':result['original_unchanged']}))
if __name__=='__main__':main()
