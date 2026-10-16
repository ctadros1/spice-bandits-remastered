"""Full original UseFreeze, ProcessSpeed and ProcessFreeze in update order.
Supplied pointer/countdown, resource speed, state, pending slowdown/tracker.
No constructor, countdown producer, manager eligibility/attachment, movement,
room lifecycle or GPU executes. Explicit fields and raw float32 bits retained.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_owner_reference import *
class Freeze(OwnerProbe):
 def sequence(self,state,existing,tracker,slow):
  self.reset();self.u.mem_write(E+0x170,bytes([state]));self.u.mem_write(E+0x250,I(E+0x1000));self.u.mem_write(E+0x1014,I(1000));self.u.mem_write(E+0x228,F(1));self.u.mem_write(E+0x22c,F(1));self.u.mem_write(E+0x208,I(17));self.u.mem_write(E+0x20c,I(E+0x4000 if existing else 0));self.u.mem_write(E+0x4000,I(77));self.u.mem_write(E+0x2d8,I(E+0x2000 if tracker else 0));self.u.mem_write(E+0x2004,I(17));self.u.mem_write(E+0x3000,I(2))
  self.invoke(0x7bc1c,[E,E+0x3000])
  bits=lambda off:struct.unpack('<I',self.u.mem_read(E+off,4))[0]
  ptr=lambda:bits(0x20c)-E if bits(0x20c) else 0
  result={'attached_pointer':ptr(),'tracker_after_attach':bits(0x2004),'frames':[]}
  for count in [2,1,0,-1,-2]:
   self.u.mem_write(E+0x3000,struct.pack('<i',count));self.u.mem_write(E+0x230,F(slow));self.invoke(0x7a924,[E]);before=ptr();multiplier=bits(0x70);self.invoke(0x7bc3c,[E])
   result['frames'].append({'counter':count,'pointer_before_freeze':before,'pointer_after_freeze':ptr(),'remaining':struct.unpack('<i',self.u.mem_read(E+0x208,4))[0],'multiplier_bits':multiplier,'tracker':bits(0x2004),'consumed_slow':self.u.mem_read(E+0x235,1)[0]})
  return result
def main():
 p=Freeze();cases=[]
 for state in range(8):
  for existing in [False,True]:
   for tracker in [False,True]:
    for slow in [-1,.6]:
     inp=dict(state=state,existing=existing,tracker=tracker,slow=slow);cases.append({'input':inp,'output':p.sequence(**inp)})
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'cases':cases};Path('tests/fixtures/native-creep-animation-freeze-reference.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'frames':sum(len(c['output']['frames']) for c in cases),'original_unchanged':result['original_unchanged']}))
 for c in cases:
  if c['input']==dict(state=0,existing=False,tracker=True,slow=-1):print(c)
if __name__=='__main__':main()
