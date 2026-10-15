"""Execute the preserved RGBA-to-gray function against boundary byte samples."""
from native_creep_reference import *
import importlib.util
from PIL import Image
spec=importlib.util.spec_from_file_location('original_importer','tools/importers/import_original.py')
importer=importlib.util.module_from_spec(spec);spec.loader.exec_module(importer)
pixels=[(r,g,b,a) for a in [0,1,64,128,254,255] for r,g,b in [(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(17,41,93),(254,143,64)]]
probe=Probe();probe.u.mem_write(E,I(E+0x1000));probe.u.mem_write(E+0x1000,bytes(v for p in pixels for v in p))
probe.u.reg_write(UC_ARM_REG_SP,STACK-32);probe.u.reg_write(UC_ARM_REG_LR,END|1)
for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2],[E,len(pixels),1]):probe.u.reg_write(r,v)
probe.u.emu_start(0x12542d,END,count=100000)
assert probe.u.reg_read(UC_ARM_REG_PC)==END
native=bytes(probe.u.mem_read(E+0x1000,len(pixels)*4))
# Convert the original output to the same straight-alpha representation used
# in Godot. Opaque and partially transparent samples remain independent ARM
# math comparisons; the original UIImage loader is outside this probe.
expected=[]
for i in range(len(pixels)):
 value,_,_,alpha=native[i*4:i*4+4]
 if 0<alpha<255:value=min(255,(value*255+alpha//2)//alpha)
 expected.extend((value,value,value,alpha))
actual=importer.native_grayscale(Image.frombytes('RGBA',(len(pixels),1),bytes(v for p in pixels for v in p))).tobytes()
report={'checks':len(pixels)*4,'failures':[i for i in range(len(actual)) if actual[i]!=expected[i]],'source_sha256':EXPECTED_SHA,'originals_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA,'method':__doc__}
Path('tests/fixtures/native-grayscale-reference.json').write_text(json.dumps({'pixels':pixels,'native_rgba':list(native),'report':report},indent=2)+'\n')
Path('builds/grayscale-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report));raise SystemExit(bool(report['failures']))
