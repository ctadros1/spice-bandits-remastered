"""Execute original premultipliedRGBA percentage grayscale on boundary samples."""
from native_creep_reference import *
import importlib.util
from PIL import Image
spec=importlib.util.spec_from_file_location('original_importer','tools/importers/import_original.py')
importer=importlib.util.module_from_spec(spec);spec.loader.exec_module(importer)
pixels=[(r,g,b,a) for a in [0,1,64,128,254,255] for r,g,b in [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(17,41,93),(254,143,64)]]
probe=Probe();cases=[];failures=[]
for fraction in [0,.25,.5,.75,1]:
 probe.u.mem_write(E,I(E+0x1000));probe.u.mem_write(E+0x1000,bytes(v for p in pixels for v in p))
 probe.u.reg_write(UC_ARM_REG_SP,STACK-32);probe.u.reg_write(UC_ARM_REG_LR,END|1)
 for reg,value in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,len(pixels),1,BITS(fraction)]):probe.u.reg_write(reg,value)
 probe.u.emu_start(0x12534d,END,count=100000);assert probe.u.reg_read(UC_ARM_REG_PC)==END
 native=bytes(probe.u.mem_read(E+0x1000,len(pixels)*4));expected=[]
 for i in range(len(pixels)):
  r,g,b,alpha=native[i*4:i*4+4]
  if 0<alpha<255:r,g,b=[min(255,(v*255+alpha//2)//alpha) for v in (r,g,b)]
  expected.extend((r,g,b,alpha))
 actual=importer.native_grayscale(Image.frombytes('RGBA',(len(pixels),1),bytes(v for p in pixels for v in p)),fraction).tobytes()
 failures.extend((fraction,i) for i in range(len(actual)) if actual[i]!=expected[i]);cases.append({'fraction':fraction,'native_rgba':list(native)})
report={'checks':len(pixels)*4*len(cases),'failures':failures,'original_sha256':EXPECTED_SHA,'originals_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'method':__doc__+' Float32/truncation before explicit unpremultiplication. Image loading/GL blending remain outside scope.'}
Path('tests/fixtures/native-gray-percentage-reference.json').write_text(json.dumps({'pixels':pixels,'cases':cases,'report':report},indent=2)+'\n');Path('builds/gray-percentage-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));raise SystemExit(bool(failures))
