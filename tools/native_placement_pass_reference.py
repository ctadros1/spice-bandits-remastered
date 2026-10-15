"""Full original room/map routing for placement controls with draw stubs.

Reuses the original RenderProbe and records each actual preview/grid/tower
callback. Supplied owner vectors and manager flags replace construction;
no original pixels, input, timers, registration lifetime or whole game.
"""
from native_render_pass_reference import *


def main():
 p=RenderProbe();cases=[]
 for name,flags in [('none',{}),('tower',{'tower':True}),('tower-grid',{'tower':True,'grid':True}),('mine-grid',{'mine':True,'grid':True}),('portal-grid',{'portal':True,'grid':True}),('grid',{'grid':True}),('all',{'tower':True,'mine':True,'portal':True,'grid':True})]:
  cases.append({'name':name,'types':[1,2],'flags':flags,'output':p.frame([1,2],flags)})
 result={'method':__doc__,'source_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path('tests/fixtures/native-placement-pass-reference.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'cases':len(cases),'callbacks':sum(len(c['output']['calls']) for c in cases),'original_unchanged':result['original_unchanged']}))


if __name__=='__main__':main()
