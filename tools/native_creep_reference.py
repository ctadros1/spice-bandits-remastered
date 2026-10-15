"""Bounded ARMv7 execution of recovered corner math; not an iOS emulator.

Requires Unicorn2.1.4 under work/reference-runtime. No original bytes are
changed. UIKit, audio, animation lifetimes, rendering and a whole game are not
executed. Narrow animator name calls are stubbed; only math fields are captured.
"""
import sys, struct, json, hashlib, argparse
from pathlib import Path
sys.path.insert(0,str(Path('work/reference-runtime').resolve()))
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_THUMB, UC_HOOK_CODE, UcError
from unicorn.arm_const import *

EXE=Path('original/game-files/ipa-1.14/Payload/Tower.app/Tower')
RAW=EXE.read_bytes()
EXPECTED_SHA='e3d230b954e1fb04e7120a20ed71df2cafaf4cd59cae73d1bf975427de7f6048'
assert hashlib.sha256(RAW).hexdigest() == EXPECTED_SHA
E=0x800000; STACK=0x900000; MEMORY=0xa00000; END=0x8f0000
F=lambda f: struct.pack('<f',f)
I=lambda n: struct.pack('<I',n)
BITS=lambda f: struct.unpack('<I',F(f))[0]
NAMES={(0,1):'RunDown',(0,-1):'RunUp',(1,1):'RunDownRight',(1,-1):'RunUpRight',(-1,1):'RunDownLeft',(-1,-1):'RunUpLeft',(1,0):'RunRight',(-1,0):'RunLeft'}
class Probe:
 def __init__(self):
  self.u=Uc(UC_ARCH_ARM,UC_MODE_THUMB)
  self.u.mem_map(0x1000,0x500000)
  for s in json.load(open('original/analysis/sections.json')):
   if s['offset'] and s['size']:self.u.mem_write(s['addr'],RAW[s['offset']:s['offset']+s['size']])
  self.u.mem_map(E,0x300000)
  self.u.mem_write(0x40a020,I(END+100))
  self.u.mem_write(END+100,I(0xabcd1234))
  self.u.reg_write(UC_ARM_REG_C1_C0_2,0xf<<20)
  self.u.reg_write(UC_ARM_REG_FPEXC,0x40000000)
  self.names={};self.strings={};self.current='RunDown';self.stop=END;self.future=(0,0);self.movement_mode=False
  self.u.hook_add(UC_HOOK_CODE,self.hook)
 def point(self,a,xy):self.u.mem_write(a,struct.pack('<2f',*xy))
 def string(self,addr):
  out=bytearray()
  for i in range(300):
   v=self.u.mem_read(addr+i,1)[0]
   if not v: return out.decode()
   out.append(v)
  raise RuntimeError('long string')
 def intern(self,s):
  if s not in self.strings:
   a=MEMORY+len(self.strings)*100;self.u.mem_write(a,s.encode()+b'\0');self.strings[s]=a
  return self.strings[s]
 def ret(self,r0=None):
  if r0 is not None:self.u.reg_write(UC_ARM_REG_R0,r0)
  self.u.reg_write(UC_ARM_REG_PC,self.u.reg_read(UC_ARM_REG_LR))
 def hook(self,u,a,size,data):
  if a==self.stop:u.emu_stop();return
  r0,r1,r2=[u.reg_read(x) for x in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2]]
  if a==0x36ca5c:self.ret()
  elif a==0x7ba04:
   self.point(r1,self.future)
   if self.movement_mode:self.u.mem_write(r2,I(2));self.u.mem_write(self.u.reg_read(UC_ARM_REG_R3),I(3))
   self.ret(1)
  elif self.movement_mode and a==0x1066fc:self.ret(0)
  elif self.movement_mode and a==0x7d108:self.ret()
  elif a==0x7acac:self.names[E+0x4c]=self.current;self.ret()
  elif a==0x7f32c:self.names[E+0xc0]=self.current;self.ret()
  elif a==0x10f0cc:self.names[r0]=self.string(r1);self.ret()
  elif a==0x10f01c:self.ret(self.intern(self.names.get(r0,self.current)))
  elif a==0x79f30:self.point(r1,(0,1));self.ret()
  elif a==0x110524:self.ret(0)
  elif a==0x36c33c:raise RuntimeError('stack guard failed')
 def turn(self, semi, current, p):
  self.stop=END
  self.u.mem_write(E,bytes(2048));self.current=NAMES[current]
  # Initial primary animator: incoming run in the second half, previous
  # semicorner in the first quarter. Only the final heading uses name stubs.
  self.names={E+0x4c:self.current,E+0xc0:self.current}
  self.point(E+0x180,current);self.point(E+0x1a0,(0,0));self.point(E+0x1a8,current)
  self.point(E+0x400,(0,0));self.point(E+0x410,semi)
  self.u.mem_write(E+0x250,I(E+0x500));self.u.mem_write(E+0x504,I(1));self.u.mem_write(E+0x34,F(1))
  self.u.reg_write(UC_ARM_REG_SP,STACK-16);self.u.reg_write(UC_ARM_REG_LR,END|1)
  for r,v in zip([UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3],[E,E+0x400,E+0x410,BITS(p)]):self.u.reg_write(r,v)
  try:self.u.emu_start(0x7d471,END,count=10000)
  except UcError as err:raise RuntimeError(f'{err}; PC={hex(self.u.reg_read(UC_ARM_REG_PC))}')
  vals={name:struct.unpack('<f',self.u.mem_read(E+offset,4))[0] for name,offset in [('rotation',0x7c),('alpha',0x80),('blend_rotation',0xf0),('blend_alpha',0xf4)]}
  vals['names']=dict(self.names);return vals
 def prepare(self, current, future, p):
  self.u.mem_write(E,bytes(2048));self.stop=0x7c318
  b=tuple(v*100 for v in current);self.future=tuple(b[i]+future[i]*100 for i in range(2))
  self.point(E+0x180,b);self.point(E+0x188,tuple(v*p for v in b));self.point(E+0x1a8,current)
  self.u.mem_write(E+0x158,F(p))
  self.u.reg_write(UC_ARM_REG_SP,STACK-16);self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,BITS(30));self.u.reg_write(UC_ARM_REG_R2,0)
  self.u.emu_start(0x7bfa9,self.stop,count=10000)
  return {'active':self.u.mem_read(E+0x2a2,1)[0], 'start':struct.unpack('<2f',self.u.mem_read(E+0x308,8)), 'end':struct.unpack('<2f',self.u.mem_read(E+0x310,8))}
 def position(self, p, logical, start, end):
  self.u.mem_write(E,bytes(2048));self.stop=END
  self.u.mem_write(E+0x2a2,b'\x01');self.u.mem_write(E+0x158,F(p))
  self.point(E+0x188,logical);self.point(E+0x308,start);self.point(E+0x310,end)
  self.u.reg_write(UC_ARM_REG_SP,STACK-16);self.u.reg_write(UC_ARM_REG_LR,END|1)
  self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,1)
  self.u.emu_start(0x7d109,END,count=10000)
  return struct.unpack('<2f',self.u.mem_read(E+0x4c,8))
 def movement(self,p,carry,speed,start,target,future,dt=30,hex_height=64):
  self.u.mem_write(E,bytes(2048));self.stop=0x7ca50;self.movement_mode=True;self.future=future
  self.point(E+0x1a0,start);self.point(E+0x180,target)
  self.point(E+0x188,tuple(start[i]+(target[i]-start[i])*p for i in range(2)))
  self.u.mem_write(E+0x158,F(p));self.u.mem_write(E+0x364,F(carry));self.u.mem_write(E+0x224,F(speed))
  self.u.mem_write(E+0x2a0,b'\x01');self.u.mem_write(E+0x2a3,b'\x01')
  self.u.mem_write(E+0x1c,I(E+0x600));self.u.mem_write(E+0x674,I(E+0x700))
  self.u.mem_write(0x40a1ec,I(MEMORY+9000));self.u.mem_write(MEMORY+9000,F(hex_height))
  self.u.reg_write(UC_ARM_REG_SP,STACK-16);self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,BITS(dt));self.u.reg_write(UC_ARM_REG_R2,0)
  self.u.emu_start(0x7bfa9,self.stop,count=10000);self.movement_mode=False
  return {'progress':struct.unpack('<f',self.u.mem_read(E+0x158,4))[0], 'carry':struct.unpack('<f',self.u.mem_read(E+0x364,4))[0],
          'position':struct.unpack('<2f',self.u.mem_read(E+0x188,8)), 'start':struct.unpack('<2f',self.u.mem_read(E+0x1a0,8)),
          'target':struct.unpack('<2f',self.u.mem_read(E+0x180,8))}

if __name__=='__main__':
 parser=argparse.ArgumentParser()
 parser.add_argument('--output',default='builds/native-creep-reference.json')
 args=parser.parse_args()
 probe=Probe();turns=[];corners=[];positions=[];movement=[];variable_movement=[]
 for p in [0.0,0.05,0.124,0.125,0.2,0.249,0.5,0.55,0.624,0.625,0.7,0.749]:
  for semi in [(-1,1),(1,1),(-1,-1),(1,-1),(-1,0),(1,0)]:
   for current in NAMES:
    result=probe.turn(semi,current,p)
    result.pop('names') # Name stubs are not an original animation oracle.
    turns.append({'p':p,'semi':semi,'current':current,**result})
 for current in NAMES:
  for future in NAMES:
   corners.append({'current':current,'future':future,**probe.prepare(current,future,.75)})
 for p,logical in [(0.8,(0,80)),(0.95,(0,95)),(0.05,(5,105)),(0.2,(20,120)),(0.3,(30,130))]:
  start,end=(0,75),(25,125)
  positions.append({'p':p,'logical':logical,'start':start,'end':end,'result':probe.position(p,logical,start,end)})
 for speed in [0,250,600,1000,12000]:
  for p in [0,.5,.75,.99,1]:
   for target in [(0,64),(80,32),(128,0)]:
    for carry in [0,.018,.3]:
     start=(0,0);future=(target[0]+80,target[1]+32)
     movement.append({'p':p,'carry':carry,'speed':speed,'start':start,'target':target,'future':future,
                      'dt':30,'hex_height':64, 'result':probe.movement(p,carry,speed,start,target,future)})
 for dt in [1,8.333333,16.67,33.333333,66.666667,100,133,533]:
  for speed in [600,1000,12000]:
   for p in [0,.75,.99,1]:
    for target in [(0,64),(80,32),(128,0)]:
     for carry in [0,.018]:
      start=(0,0);future=(target[0]+80,target[1]+32)
      variable_movement.append({'p':p,'carry':carry,'speed':speed,'start':start,'target':target,'future':future,
                                'dt':dt,'hex_height':64,'result':probe.movement(p,carry,speed,start,target,future,dt)})
 record={'reference_sha256':EXPECTED_SHA,'unicorn_version':'2.1.4',
         'method':'Isolated preserved ARMv7 instructions: UpdateMovementAndShooting entry through0x7c318 for corner preparation; UpdatePosition0x7d108 with animation disabled; InterpolatePhysicalRotation0x7d470 math fields. Animator-name/framework calls are stubs. Not a working original iOS game or runtime presentation parity.',
         'stubs':{'0x1066fc':'Movement-only GetCell returns null; cell-height interpolation excluded',
                  '0x7d108':'Movement-only UpdatePosition returns without rendering; separately tested above',
                  '0x7acac':'UpdateDirection supplies a known current animation name',
                  '0x7f32c':'UpdateDirectionBlending supplies a known current name',
                  '0x10f0cc':'PlayAnimation records the requested name',
                  '0x10f01c':'GetCurrentAnimName returns that recorded name',
                  '0x79f30':'ConvertDirections supplies(0,1); only final heading uses it and that heading is excluded',
                  '0x110524':'AngPos returns0; its final heading is excluded',
                  '0x7ba04':'GetFirstMovementPoint supplies the given next endpoint and movement-only cell indices',
                  '0x36ca5c':'Unwind registration returns without action'},
         'turns':turns,'corners':corners,'positions':positions,'movement':movement,'variable_movement':variable_movement,
         'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
 Path(args.output).write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'turns':len(turns),'corners':len(corners),'positions':len(positions),'movement':len(movement),'original_unchanged':record['original_unchanged']}))
