"""Read-only R173 original GetDist2D(int*,int*) input/output probe.
The complete unchanged40-byte body executes with supplied signed integer
coordinates. No callbacks, movement callers, route/room state or GPU execute.
The grid is supplied math coverage, not a claim all pairs occur on game maps.
"""
from pathlib import Path
import sys,struct,itertools,json,hashlib,argparse
sys.path.insert(0,str(Path('tools').resolve()))
from native_creep_reference import *
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args();p=Probe();u=p.u;body=bytes(u.mem_read(0x1104e0,40));rows=[]
 for x,y,a,b in itertools.product([-64,-32,-8,-1,0,1,8,32,64],repeat=4):
  first=E+0x1000;second=E+0x2000;u.mem_write(first,struct.pack('<2i',x,y));u.mem_write(second,struct.pack('<2i',a,b));u.reg_write(UC_ARM_REG_R0,first);u.reg_write(UC_ARM_REG_R1,second);u.reg_write(UC_ARM_REG_SP,STACK-16);u.reg_write(UC_ARM_REG_LR,END|1);u.emu_start(0x1104e1,END,count=1000)
  assert u.reg_read(UC_ARM_REG_PC)==END and bytes(u.mem_read(0x1104e0,40))==body
  rows.append({'first':[x,y],'second':[a,b],'distance':u.reg_read(UC_ARM_REG_R0)})
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 result={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_unchanged':True,'body_address':'0x1104e0','body_bytes':40,'body_sha256':hashlib.sha256(body).hexdigest(),'cases':rows};out=Path(args.output);assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original_unchanged':True}),flush=True)
if __name__=='__main__':main()
