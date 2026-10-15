"""Original CLevelItem constructor prefix through fourteen text objects.

Allocation, C++ strings/streams and CTextObject construction are recording
stubs. The original constructor declarations and three blurShadow setters
execute. Device type is supplied; stop0x8476a before later callback setup.
No font raster, real device service or UIKit compositor.
"""
from native_creep_reference import *

class TextProbe(Probe):
 def hook(self,u,a,size,data):
  if a==0x8476a:u.emu_stop();return
  r0,r1,r2,r3=[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]
  if a==0x36c1bc:
   ptr=E+0x1000+len(self.allocations)*0x100;self.allocations.append(ptr);self.ret(ptr);return
  if a==0x36c04c:self.names[r0]=self.string(r1);self.ret();return
  if a in [0x36c00c,0x36c06c,0x36c0ac]:self.ret();return
  if a==0x36c97c:self.ret(len(self.string(r0)));return
  if a==0x36be6c:
   name=self.string(r1);assert name in ['sharedGlobals','deviceType'],name
   self.ret(self.device if name=='deviceType' else E+0x7000);return
  if a==0x1224b4:self.ret();return
  if a==0x1221b0:
   self.texts.append({'target':r0-E,'font':self.names[r1],'size':struct.unpack('<f',I(r2))[0],'color':list(struct.unpack('<4f',I(r3)+u.mem_read(u.reg_read(UC_ARM_REG_SP),12)))})
   self.ret(r0);return
  if a==0x1226cc:
   self.shadows.append({'target':r0-E,'enabled':bool(r1),'blur':struct.unpack('<f',I(r2))[0],'intensity':r3,'colors':list(struct.unpack('<8f',u.mem_read(u.reg_read(UC_ARM_REG_SP),32)))})
  super().hook(u,a,size,data)
 def run(self,device):
  self.device=device
  self.u.mem_write(E,bytes(0x8000));self.u.mem_write(STACK-4096,bytes(8192));self.names={};self.allocations=[];self.texts=[];self.shadows=[];self.finish=None
  self.u.reg_write(UC_ARM_REG_SP,STACK);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for reg,val in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,E+0x7000,1,E+0x7100]):self.u.reg_write(reg,val)
  self.u.mem_write(STACK,I(self.intern('Normal'))+I(self.intern('Normal')))
  self.u.emu_start(0x83d6d,END,count=100000)
  assert self.u.reg_read(UC_ARM_REG_PC)==0x8476a and len(self.shadows)==3
  for s in self.shadows:
   obj=E+s['target'];s['written']={'enabled':bool(self.u.mem_read(obj+0x5f,1)[0]),'blur':struct.unpack('<f',self.u.mem_read(obj+0x64,4))[0],'intensity':struct.unpack('<I',self.u.mem_read(obj+0x60,4))[0],'colors':list(struct.unpack('<8f',self.u.mem_read(obj+0x68,32)))}
  roles={name:struct.unpack('<I',self.u.mem_read(E+offset,4))[0]-E for name,offset in [('locked_title',8),('shadow_title',12),('completed_title',16),('new_title',20),('description',64),('points',72)]}
  return {'device_type':device,'texts':self.texts,'shadows':self.shadows,'roles':roles,'stopped_at':'0x8476a'}

def main():
 p=TextProbe();record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':[p.run(device) for device in [1,2]],'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-mode-text-reference.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'text_objects':sum(len(c['texts']) for c in record['cases']),'shadows':sum(len(c['shadows']) for c in record['cases']),'original_unchanged':record['original_unchanged']}))

if __name__=='__main__':main()
