"""R172 original constructor-derived authored offsets plus unchanged hover tail.
The full R163 constructor/factory/particle/state/hover chain supplies each
resource's primary animator offset, zero phase and hover flags. Its existing
nonparticle/animator construction/Init/position/resource/random callbacks remain
explicit stubs. Those fields then become supplied inputs to the unchanged
R164 movement tail and full state/hover selection for thirty240-frame sequences.
External sinf remains float32 math.sin, not original libm. No complete original
movement/room/Fly/portal/growth/audio/render/GPU claim; R166/R167/R168 fixtures
independently cover the selected full movement, Freeze owner and render joins.
"""
from native_creep_state_reference import FullStateConstructor
from native_creep_hover_reference import *
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();c=FullStateConstructor();h=Hover();constructors=[];sequences=[]
 for n in range(1,11):
  resource='creeps/creep'+str(n);c.sample(resource,1,1)
  word=lambda offset:struct.unpack('<I',c.u.mem_read(E+offset,4))[0]
  flags=tuple(c.u.mem_read(E+0x348,3));offset=struct.unpack('<2f',c.u.mem_read(E+0x54,8));phase=struct.unpack('<f',c.u.mem_read(E+0x344,4))[0]
  constructors.append({'resource':resource,'hover348':flags[0],'hover349':flags[1],'hover34a':flags[2],'phase_bits':word(0x344),'offset_bits':[word(0x54),word(0x58)]})
  for delta in [16.667,30,100]:
   h.prepare(*flags,phase,offset[1]);h.point(E+0x54,offset);frames=[]
   for frame in range(240):
    state=0 if frame<60 or frame>=180 else (7 if frame<120 else 4)
    h.state(state);frames.append({'frame':frame,'requested_state':state,'after':h.step(delta)})
   sequences.append({'resource':resource,'delta':delta,'hover348':flags[0],'hover349':flags[1],'initial_phase_bits':BITS(phase),'initial_offset_bits':[BITS(v) for v in offset],'frames':frames})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 assert all(bytes(c.u.mem_read(a,len(b)))==b for a,b in c.bodies.items()) and all(bytes(h.u.mem_read(a,len(b)))==b for a,b in h.bodies.items())
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'constructor_function_bytes':{hex(a):len(b) for a,b in c.bodies.items()},'hover_function_or_slice_bytes':{hex(a):len(b) for a,b in h.bodies.items()},'constructors':constructors,'sequences':sequences};path=Path(args.output);assert not path.exists();path.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'constructors':len(constructors),'sequences':len(sequences),'frames':sum(len(s['frames']) for s in sequences),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
