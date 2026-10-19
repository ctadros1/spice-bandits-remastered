from pathlib import Path
import subprocess,sys,json,time,os,signal
r=Path.cwd();b=r/'builds';sys.path.insert(0,str(r/'tools'));import run_packaged_qa as q
before=json.loads((b/'normal-r187-native-suites.json').read_text());protected=before['protected_after']
def guards():
 assert not q.app_processes(),q.app_processes()
 assert all(q.digest(Path(n))==h for n,h in protected.items())
 assert q.digest(q.PACK)==before['pck_sha256'] and q.digest(q.EXE)==before['executable_sha256'] and q.native_libraries()==before['native_libraries_sha256']
def run(script,name,headless):
 guards();start=time.monotonic();args=[str(r/'work/toolchain/Godot.app/Contents/MacOS/Godot')]+(['--headless'] if headless else [])+['--path','game','--script',str(b/script),'--','--qa'];log=b/(name+'.log')
 with log.open('x') as f:
  p=subprocess.Popen(args,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=p.wait(timeout=90)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGTERM);p.wait(timeout=15);raise
 text=log.read_text();record={'exit_code':code,'seconds':time.monotonic()-start,'clean_log':not any(k in text for k in ['SCRIPT ERROR','ERROR:','Leaked instance','ObjectDB instances were leaked']),'all_four_saves_exact':all(q.digest(Path(n))==h for n,h in protected.items()),'no_game_processes':not q.app_processes()};(b/(name+'-run.json')).write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record),flush=True);guards();assert code==0 and record['clean_log'],text[-3000:]
assert not json.loads((b/'creep-profile-r188-passthrough.json').read_text())['failures']
run('creep_profile_native_r188_live.gd','creep-profile-r188-native-live-first',False)
