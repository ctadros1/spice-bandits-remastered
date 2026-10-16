"""Original SetDie/Sprite constructor/DoOnDying/Update/Render at a visible mid-flash.
Ten preserved resource inputs, zero-delta update then five30ms updates.
Resource/particle/audio/decal/random/GL callbacks retain R124 recording stubs.
Actual sprite math/quad-size/straight color fields execute; no GPU/game runs.
"""
import sys
sys.path.insert(0,'tools')
from native_creep_death_sprite_reference import *
def main():
 p=Sprites();p.animations=json.loads(Path('game/data/animations.json').read_text());particles=json.loads(Path('game/data/particles.json').read_text());p.bindings=particles['bindings'];p.systems=particles['systems'];cases=[]
 catalog={r['address']:r for r in json.loads(Path('original/analysis/functions.json').read_text())};addresses=[0x7a150,0x7beb8,0x1214d0,0x1216c4,0x121648];bodies={a:bytes(p.u.mem_read(a,catalog[a]['size'])) for a in addresses}
 for i in range(1,11):
  resource='creeps/creep'+str(i);p.prepare(resource);birth=p.read_sprite();p.invoke(0x7beb8,[E,BITS(0)]);zero=p.read_sprite()
  for _ in range(5):p.invoke(0x7beb8,[E,BITS(30)])
  middle=p.read_sprite();assert len(middle['sprites'])==1 and middle['sprites'][0]['life_bits']==BITS(150)
  cases.append({'resource':resource,'birth':birth,'zero_delta':zero,'mid_150ms':middle})
 assert all(bytes(p.u.mem_read(a,len(b)))==b for a,b in bodies.items()) and hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 data={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_executed_bodies_unchanged':True,'cases':cases}
 Path('tests/fixtures/native-creep-splash-mid-reference.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps({'cases':len(cases),'sprite_states':len(cases)*3,'original_unchanged':True}))
if __name__=='__main__':main()
