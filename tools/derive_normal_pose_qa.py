"""Derive native-only QA inputs/expected poses from immutable original oracles.
No source fixture is modified. The game advances actual constructed actors;
expected fields are read only for checks, never injected into actor state.
"""
import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REFERENCES={'native-creep-shooting-reference.json':'30790afa94ea428d648fba8e82d749b189d8a5cc8bb7e99edc8f3e4c9a13ae54','native-creep-air-path-reference.json':'c1773610b3e72e1ffb4741a1a01e0352e2693c91fad344beeee612ca954004e4'}
def reference(name):
 p=ROOT/'tests/fixtures'/name;assert hashlib.sha256(p.read_bytes()).hexdigest()==REFERENCES[name];return json.loads(p.read_text())
def derive():
 rows=[];name='native-creep-shooting-reference.json';x=reference(name)
 for number,pose,change,phase,at in [(5,'walking','open','warmup_frames',31),(5,'approaching','open','warmup_frames',1),(5,'aligned','open','warmup_frames',63),(5,'owned-aligned','open','warmup_frames',63),(4,'walking','open','warmup_frames',31),(4,'aligned','open','warmup_frames',63),(4,'owned-aligned','open','warmup_frames',63),(4,'owned-aligned','current','frames',63)]:
  s=next(r for r in x['cases'] if r['input']['creep_number']==number and r['input']['pose']==pose and r['change']['kind']==change)
  rows.append({'name':str(number)+'-'+pose+'-'+change,'input':s['input'],'warmup_deltas':[r['delta'] for r in (s['warmup_frames'][:at+1] if phase=='warmup_frames' else s['warmup_frames'])],'change':s['change'] if phase=='frames' else None,'after_deltas':[r['delta'] for r in s['frames'][:at+1]] if phase=='frames' else [],'expected':s[phase][at]['after'],'original_fixture':name,'original_sha256':REFERENCES[name],'primary_name_verified':True})
 name='native-creep-air-path-reference.json';x=reference(name)
 for change in ['wall','kill-all']:
  s=next(r for r in x['cases'] if r['input']['pose']=='fresh' and r['change']['kind']==change)
  rows.append({'name':'4-fresh-'+change,'input':s['input'],'warmup_deltas':[r['delta'] for r in s['warmup_frames']],'change':s['change'],'after_deltas':[r['delta'] for r in s['frames']],'expected':s['frames'][-1]['after'],'original_fixture':name,'original_sha256':REFERENCES[name],'primary_name_verified':False})
 assert len(rows)==10
 return {'method':__doc__,'source_oracles':REFERENCES,'poses':rows,'limit':'Actual constructed normal actors on the original supplied16x16 QA graph. Preserved Training backdrop is a visual fixture, not original map/whole-game equivalence. HP50/100 is supplied only after exact movement checks to expose the health anchor. Owned animation frame held for facing/geometry captures; existing clock suites establish separate timing. Native portal captures are actual-C2 functional probes; full original C2/portal join is not claimed.'}
def main():
 out=ROOT/'game/data/qa-normal-poses.json';out.parent.mkdir(exist_ok=True,parents=True);text=json.dumps(derive(),indent=2)+'\n';out.write_text(text);print(json.dumps({'native_qa_poses':10,'bytes':len(text.encode()),'sha256':hashlib.sha256(text.encode()).hexdigest(),'immutable_original_fixtures_verified':True}))
if __name__=='__main__':main()
