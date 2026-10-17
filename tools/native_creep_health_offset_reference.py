"""R169 full original Creep.Render health anchoring with independent offsets.
The original health condition/float32 geometry/RGBA/UV executes with supplied
animator raw positions, authored/hover-like offsets, HP/alpha/state/resources
and texture records. Animator/body/shadow/quad/GL are recording stubs, exactly
as the earlier independent health fixture. No original constructor, full
movement/Fly/portal/GPU/room executes. This probes whether health geometry
reads the animator position or its separately stored body offset.
"""
from native_creep_health_reference import *
import argparse,itertools
class OffsetHealth(Health):
 def sample(self,kind,state,hp,alpha,point,offset):
  self.health(kind,state,hp,100,alpha,point,[0,1,0,1]);self.point(E+0x54,offset);self.calls=[];self.invoke(0x7f5c8,[E]);return [r for r in self.calls if r['method'].startswith('health')]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=OffsetHealth();cases=[]
 for kind,state,hp,alpha,point,offset in itertools.product([1,2],[0,3],[.1,50],[.35,1],[(100,150),(231.25,-50.875)],[(0,0),(0,-7),(2.25,3.5),(0,1.25)]):
  calls=p.sample(kind,state,hp,alpha,point,offset);cases.append({'input':{'kind':kind,'state':state,'hp':hp,'alpha':alpha,'point':point,'offset':offset},'calls':calls})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'cases':cases};path=Path(args.output);path.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
