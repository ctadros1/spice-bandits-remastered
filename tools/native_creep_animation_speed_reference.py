"""Full original CCreep.ProcessSpeed with supplied resource/factor/status fields.
No framework calls occur in this function. No original constructor, global
clock producer, scene, movement, whole game or GPU executes. Raw float32 bits
are retained, including zero-speed infinity. Supplied tracker is bounded.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_owner_reference import *
class Speed(OwnerProbe):
 def sample(self,base,first,second,pending,held,tracker):
  self.reset();self.u.mem_write(E+0x250,I(E+0x1000));self.u.mem_write(E+0x1014,struct.pack('<i',base))
  for off,value in [(0x228,first),(0x22c,second),(0x230,pending)]:self.u.mem_write(E+off,F(value))
  self.u.mem_write(E+0x20c,I(held));self.u.mem_write(E+0x235,b'\xff')
  self.u.mem_write(E+0x2d8,I(E+0x2000 if tracker else 0));self.u.mem_write(E+0x2004,I(17))
  self.invoke(0x7a924,[E])
  bits=lambda off:struct.unpack('<I',self.u.mem_read(E+off,4))[0]
  return {'speed_bits':bits(0x224),'primary_divisor_bits':bits(0x98),'secondary_divisor_bits':bits(0x10c),'primary_multiplier_bits':bits(0x70),'secondary_multiplier_bits':bits(0xe4),'pending_bits':bits(0x230),'consumed_slow':self.u.mem_read(E+0x235,1)[0],'tracker_value':bits(0x2004)}
def main():
 p=Speed();cases=[]
 for base in [0,1,500,1000,1500,3000]:
  for first,second in [(1,1),(.3,1),(1,1.25),(.3,1.25)]:
   for pending in [-1,0,.25,.6,1,2]:
    for held in [0,1,7]:
     for tracker in [False,True]:
      inp=dict(base=base,first=first,second=second,pending=pending,held=held,tracker=tracker);cases.append({'input':inp,'output':p.sample(**inp)})
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-animation-speed-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'original_unchanged':result['original_unchanged']}));print(cases[36])
if __name__=='__main__':main()
