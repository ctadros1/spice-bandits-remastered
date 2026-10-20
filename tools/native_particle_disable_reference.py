"""R194 original PS.Update raw seconds header boundaries on supplied empty roots.
Full unchanged 912-byte Update executes. Header/time-scale/delay/clock/first-release
records supplied. Release interval100 seconds prevents Emit in these contexts;
any attempted factory/emission fails the probe rather than fabricating particles.
No real resource parser, cloud controller, room, RNG, physics/GPU/audio runs.
"""
from pathlib import Path
import sys,json,struct,hashlib,argparse,itertools
sys.path.insert(0,'tools')
from native_creep_reference import *
def f32(v):return struct.unpack('<f',F(v))[0]
def value(bits):return struct.unpack('<f',I(bits))[0]
class DisableProbe(Probe):
 def __init__(self):
  super().__init__();self.body=bytes(self.u.mem_read(0x111088,912))
 def hook(self,u,address,size,data):
  if address==0x111418:raise AssertionError('unexpected Emit outside supplied no-emission contexts')
  super().hook(u,address,size,data)
 def sample(self,inp):
  u=self.u;u.mem_write(E,bytes(0x200))
  for off,num in [(0,100),(4,3),(0xb0,3),(0xb8,0)]:u.mem_write(E+off,I(num))
  for off,v in [(8,100),(12,1),(0x38,1),(0x3c,1),(0x40,1),(0x44,1),(0x50,inp['time_scale']),(0x4c,value(inp['disable_bits'])),(0xc0,value(inp['clock_bits'])),(0xbc,inp['delay_seconds'])]:u.mem_write(E+off,F(v))
  u.mem_write(E+0xd6,bytes([inp['first_release']]))
  u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.reg_write(UC_ARM_REG_R0,E);u.reg_write(UC_ARM_REG_R1,BITS(inp['dt_seconds']));u.emu_start(0x111089,END,count=20000)
  assert u.reg_read(UC_ARM_REG_PC)==END
  assert bytes(u.mem_read(0x111088,912))==self.body
  def word(off):return struct.unpack('<I',u.mem_read(E+off,4))[0]
  return {'rate':word(4),'clock_bits':word(0xc0),'release_bits':word(0xc4),'delay_bits':word(0xbc),'first_release':u.mem_read(E+0xd6,1)[0],'active_count':word(0xb8),'disable_bits':word(0x4c)}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args();out=Path(a.output);assert not out.exists();p=DisableProbe();rows=[]
 for duration,first,scale,dt,delay in itertools.product([0,.001,199.999,200,6000,12345.67],[0,1],[0,.5,1,2,1e-40,1.1754943508222875e-38],[0,.001,.03,.1,1e-40,1.1754943508222875e-38],[0,.02]):
  disable=f32(f32(duration)*f32(.001));bits=BITS(disable)
  for delta in [-1,0,1]:
   # A negative boundary below zero is supplied as -smallest-subnormal.
   clockbits=bits+delta if bits or delta>=0 else 0x80000001
   inp={'duration_ms':duration,'disable_bits':bits,'clock_bits':clockbits,'first_release':first,'time_scale':scale,'dt_seconds':dt,'delay_seconds':delay}
   rows.append({'input':inp,'output':p.sample(inp)})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_selected_body_unchanged':True,'body_bytes':912,'body_sha256':hashlib.sha256(p.body).hexdigest(),'cases':rows}
 out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}))
if __name__=='__main__':main()
