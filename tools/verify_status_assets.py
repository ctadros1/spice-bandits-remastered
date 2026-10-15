"""Verify screen atlases retain preserved premultiplied RGB byte-for-byte."""
import hashlib, json, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'importers'))
from import_original import cgbi_image, decode
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 mapping=json.loads((ROOT/'game/data/screen_textures.json').read_text())
 manifest=json.loads((ROOT/'game/data/import_manifest.json').read_text())['assets'];rows=[];pixels=0;partial=0
 for runtime,derived in sorted(mapping.items()):
  source=ROOT/next(a['selected'] for a in manifest if a.get('runtime')==runtime)
  data=source.read_bytes();original=cgbi_image(data,unpremultiply=False) if b'CgBI' in data[:40] else decode(source)
  if b'CgBI' not in data[:40]:
   original=Image.frombytes('RGBA',original.size,bytes(v for p in original.getdata() for v in tuple((n*p[3]+127)//255 for n in p[:3])+(p[3],)))
  actual=Image.open(ROOT/'game'/derived).convert('RGBA')
  assert actual.size==original.size and actual.convert('RGB').tobytes()==original.convert('RGB').tobytes(),runtime
  assert actual.getchannel('A').getextrema()==(255,255),derived
  pixels+=actual.width*actual.height;partial+=sum(0<a<255 for a in original.getchannel('A').getdata())
  rows.append({'source':str(source.relative_to(ROOT)),'source_sha256':digest(source),'derived':derived,'derived_sha256':digest(ROOT/'game'/derived),'pixels':actual.width*actual.height})
 result={'passed':True,'atlases':len(rows),'pixels':pixels,'partial_alpha_source_pixels':partial,'rows':rows,'scope':__doc__+' Original texture decoder is shared with deterministic importer; GPU sampling and original raster are separate.'}
 (ROOT/'builds/creep-status-assets-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rows'}))
if __name__=='__main__':main()
