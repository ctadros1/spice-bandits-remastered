"""Additional bounded original cloud damage distance/float32 caller evidence.
Uses full unchanged R190 selected bodies and explicit original R190 callbacks.
Inputs cross diagonal and strict-radius float32 boundaries with two supplied
map heights, positive nominal damage/support bonus, four dt values and three
prior exposure counts. No actual resource parser, damage or whole game runs.
"""
import sys,itertools,argparse,json,hashlib
from pathlib import Path
sys.path.insert(0,'tools')
from native_creep_poison_callers_reference import PoisonProbe,E,F,BITS,EXE,EXPECTED_SHA

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args();out=Path(a.output);assert not out.exists();p=PoisonProbe();rows=[]
 offsets=[(0,0),(.25,.125),(1.2,1.5),(1.1999998,1.5999999),(1.2,1.6),(1.2000002,1.6000002),(1.9999999,0),(2,0),(2.0000002,0),(-1.9,.5),(.03125,-.09375),(-.625,1.375)]
 for delta,height,damage,bonus,counter,dt in itertools.product(offsets,[32,45.333333333333],[10,35],[0,2.5],[0,1,3],[0,16.667,30,100]):
  actors=[{'pos':[100+delta[0]*height,150+delta[1]*height],'poison_count':counter,'initial_rate':0}];clouds=[{'pos':[100,150],'damage':damage,'bonus':bonus}]
  action={'kind':'damage','dt_ms':dt};p.setup_clouds(actors,clouds);p.u.mem_write(E+0x4000,F(height));p.events=[];p.invoke(0xe17c0,[p.clouds[0],BITS(dt),0]);rows.append({'input':{'actors':actors,'clouds':clouds,'actions':[action],'height':height,'damage_stub_sets_state3_for':None},'frames':[p.snapshot()]})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 report={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_executed_bodies_unchanged':True,'bodies':{hex(a):{'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for a,b in p.bodies.items()},'sequences':rows}
 out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}))
if __name__=='__main__':main()
