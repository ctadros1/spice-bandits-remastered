"""R176 full original displacement reservation/free lifetime on supplied cells.
CreateDisplacePoints, GetDisplacePointInHexagon and FreeDisplacePointInHexagon
execute unchanged with explicit memory/exception callbacks and supplied map,
cell/world point, global hex distance and owner ids. The free routine retains
owner ids and returns after its first match even when that slot is already free.
Owner0 cases expose original zero-initialized free owner fields. No actor/room
or original map producer, death owner caller, renderer or GPU executes.
"""
from native_creep_hex_reference import *
class Lifetime(HexProbe):
 def __init__(self):
  super().__init__();a=0x10b904;self.addresses.append(a);fs=json.load(open('original/analysis/functions.json'));self.bodies[a]=bytes(self.u.mem_read(a,next(x['size'] for x in fs if x['address']==a)))
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();p=Lifetime();rows=[]
 for cell,height,owner in itertools.product([(0,0),(4,4)],[48,64],[0,1,9001]):
  p.setup([cell]);u=p.u;u.mem_write(0x47eda0,F(height));center=struct.unpack('<2f',u.mem_read(p.cells[cell]+0x10,8));toward=(center[0]+100,center[1]);p.point(E+0x5000,toward);frames=[]
  actions=[('reserve',owner)]*3+[('free',owner)]*3+[('reserve',owner+1),('free',owner),('reserve',owner),('free',owner+1),('free',owner)]+[('reserve',owner)]*8+[('free',owner)]*2
  for action,actor in actions:
   point=None
   if action=='reserve':p.point(E+0x5100,(-9,-9));p.call(0x10b954,[p.map,*cell,actor],[E+0x5000,E+0x5100]);point=list(struct.unpack('<2I',u.mem_read(E+0x5100,8)))
   else:p.call(0x10b904,[p.map,*cell,actor])
   slots=p.slots(cell);frames.append({'action':action,'owner':actor,'point_bits':point,'active_owners':[-1 if s['free'] else s['owner'] for s in slots],'retained_owners':[s['owner'] for s in slots]})
  rows.append({'input':{'cell':cell,'height':height,'center':center,'toward':toward},'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'full_function_bytes':{hex(a):len(b) for a,b in p.bodies.items()},'sequences':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'sequences':len(rows),'calls':sum(len(r['frames']) for r in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}),flush=True)
if __name__=='__main__':main()
