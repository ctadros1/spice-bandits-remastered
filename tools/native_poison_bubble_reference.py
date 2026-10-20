"""R197 bounded unchanged original CPoisonBubble constructor/Update/Render/destructor.
Supplied resource, target lookup, texture allocation/construct/destruct, parameter
lookup, draw/blend/color, particle factory/update/status/render/destructor and memory helpers are explicit
callbacks. Reserved vector capacity is supplied before push_back. Original
interpolation/distance arithmetic executes. No complete game, GPU, original
particle physics, owner/room schedule or resource parser executes.
"""
import sys,json,struct,itertools,hashlib,argparse
from pathlib import Path
sys.path.insert(0,'tools')
from native_poison_lifecycle_reference import *
class Bubble(Lifecycle):
 def __init__(self):
  super().__init__();self.target=None;self.textures={};self.allocation=E+0xe0000;self.parameter=None;self.factory_null=False;self.null_names=[];self.supplied_header={}
  catalog=json.loads(Path('original/analysis/functions.json').read_text())
  for a in [0xe1c24,0xe1f54,0xe1f64,0xe21d0,0xe20b8,0x1105e4,0x1107e8,0x1104b0]:
   self.bodies[a]=bytes(self.u.mem_read(a,next(r['size'] for r in catalog if r['address']==a)))
 def root(self,name='supplied'):
  p=super().root(name)
  for off,key in [(4,'rate'),(8,'interval'),(0x4c,'disable'),(0xb8,'count')]:
   if key in self.supplied_header:self.u.mem_write(p+off,I(int(self.supplied_header[key]) & 0xffffffff) if key in ['rate','count'] else F(self.supplied_header[key]))
  if 'first' in self.supplied_header:self.u.mem_write(p+0xd6,bytes([self.supplied_header['first']]))
  return p
 def hook(self,u,a,size,data):
  r0=u.reg_read(UC_ARM_REG_R0);r1=u.reg_read(UC_ARM_REG_R1)
  if a==0x11515c:
   self.events.append({'kind':'blend_stub','source':r0,'destination':r1});self.ret();return
  if a==0x36b2ac:
   self.events.append({'kind':'color_stub','rgba_bits':[u.reg_read(r) for r in [UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3]]});self.ret();return
  if a==0x1152d0:
   self.events.append({'kind':'quad_stub','name':self.textures[r0],'texture_slot':next(off for off in [0x4c,0x50] if self.word(E+off)==r0),'size':[self.word(r0+8),self.word(r0+12)],'xy_bits':[r1,u.reg_read(UC_ARM_REG_R2)]});self.ret();return
  if a==0x111880:
   self.events.append({'kind':'particle_render_stub','id':self.ps[r0]['id']});self.ret();return
  if a==0xfb980:
   self.events.append({'kind':'target_lookup_stub','id':r0,'present':self.target is not None})
   if self.target is not None:self.point(E+0x60190,self.target)
   self.ret(E+0x60000 if self.target is not None else 0);return
  if a==0x11794c:
   self.events.append({'kind':'resource_parameter_stub','name':self.string(r1),'value':self.parameter})
   if self.parameter is not None:u.mem_write(E+0x61008,I(self.parameter & 0xffffffff))
   self.ret(E+0x61000 if self.parameter is not None else 0);return
  if a==0x36c1bc:
   self.allocation+=0x100;u.mem_write(self.allocation,bytes(0x100));self.events.append({'kind':'allocation_stub','bytes':r0});self.ret(self.allocation);return
  if a==0x125cdc:
   name=self.string(r1);self.textures[r0]=name;v=E+0x62000;u.mem_write(v+4,I((END+0x2000)|1));u.mem_write(r0,I(v));sp=u.reg_read(UC_ARM_REG_SP);w=self.word(sp);h=self.word(sp+4);u.mem_write(r0+8,struct.pack('<2I',w,h));self.events.append({'kind':'texture_constructor_stub','name':name,'crop_origin':[u.reg_read(UC_ARM_REG_R2),u.reg_read(UC_ARM_REG_R3)],'supplied_header_from_requested_size':[w,h]});self.ret(r0);return
  if a==END+0x2000:
   self.events.append({'kind':'texture_destructor_stub','name':self.textures[r0]});self.ret();return
  if a==0x81bb0 and self.word(r0)==0:
   start=E+0xb000;u.mem_write(r0,struct.pack('<3I',start,start,start+512))
  if a==0x111834 and (self.factory_null or self.string(r0) in self.null_names):
   self.events.append({'kind':'factory_stub_null','name':self.string(r0)});self.ret(0);return
  if a==0x36c18c and r0 not in self.ps:
   self.events.append({'kind':'vector_storage_delete_stub' if r0==E+0xb000 else 'other_delete_stub'});self.ret();return
  super().hook(u,a,size,data)
 def state(self):
  start,end=struct.unpack('<2I',self.u.mem_read(E+0x54,8));assert end>=start and end-start<=512
  roots=[]
  for at in range(start,end,4):
   p=self.word(at);n=self.ps[p];roots.append({'id':n['id'],'name':n['name'],'rate':self.word(p+4),'interval_bits':self.word(p+8),'disable_after_bits':self.word(p+0x4c),'position_bits':[self.word(p+0xa0),self.word(p+0xa4)],'active_count':struct.unpack('<i',self.u.mem_read(p+0xb8,4))[0],'first_release':self.u.mem_read(p+0xd6,1)[0],'update_calls':n['updates']})
  return {'words':{hex(off):self.word(E+off) for off in range(4,0x44,4)},'flags':list(self.u.mem_read(E+0x44,4)),'target_id':self.word(E+0x48),'texture_sizes':[[self.word(E+off+0) and self.word(self.word(E+off)+8),self.word(E+off) and self.word(self.word(E+off)+12)] for off in [0x4c,0x50]],'roots':roots,'events':self.events.copy()}
 def render_events(self):
  before=bytes(self.u.mem_read(E,0x100));self.events=[];self.invoke(0xe20b8,[E]);assert bytes(self.u.mem_read(E,0x100))==before
  return self.events.copy()
 def sequence(self,inp):
  self.setup_clouds([],[]);self.u.mem_write(E,bytes(0x100));self.ps={};self.serial=0;self.textures={};self.allocation=E+0xe0000;self.parameter=inp.get('height');self.target=inp.get('target');self.factory_null=inp.get('factory_null',False);self.null_names=inp.get('null_names',[]);self.supplied_header=inp.get('particle_header',{});self.stub_frames=inp.get('particle_counts',[2,0]);self.tail_ms=0
  d=E+0x8000;self.u.mem_write(d+0x8a,bytes([inp['slow']]));self.u.mem_write(d+0x8c,I(E+0x64000));self.point(E+0x6000,inp['start']);self.u.mem_write(STACK-0x1000,I(inp['follow']));self.events=[]
  self.invoke(0xe1c24,[E,d,E+0x6000,77]);ctor=self.state();ctor['render_events']=self.render_events();frames=[]
  if 'supplied_flags' in inp:self.u.mem_write(E+0x44,bytes(inp['supplied_flags']))
  if 'supplied_roots' in inp:
   start=E+0xb000
   self.u.mem_write(E+0x54,struct.pack('<3I',start,start,start+512))
   for i,h in enumerate(inp['supplied_roots']):
    self.supplied_header=h;q=self.root('supplied-status-'+str(i));self.u.mem_write(start+4*i,I(q))
   self.u.mem_write(E+0x58,I(start+4*len(inp['supplied_roots'])))
  for i,dt in enumerate(inp['deltas']):
   if 'targets' in inp:self.target=inp['targets'][i%len(inp['targets'])]
   self.events=[];self.invoke(0xe21d0,[E,BITS(dt),inp.get('argument_b',0)]);state=self.state();state['render_events']=self.render_events();frames.append(state)
  self.events=[];self.invoke(0xe1f54,[E]);destructor=self.state()
  return {'input':inp,'constructor':ctor,'frames':frames,'destructor':destructor}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);args=ap.parse_args();out=Path(args.output);assert not out.exists();p=Bubble();rows=[]
 for slow,follow,height,target,deltas,missing in itertools.product([0,1],[0,1],[None,0,25],[[160,260],None],[[30]*50,[0,100,400,500,600,1000,30,30]], [False,True]):
  rows.append(p.sequence({'slow':slow,'follow':follow,'height':height,'target':target,'start':[100,200],'deltas':deltas,'factory_null':missing}))
 base={'slow':0,'follow':1,'height':25,'target':[160,260],'start':[100,200],'deltas':[30]*50}
 # Supplied target moves/loss, arbitrary second argument, two families and flags.
 for slow,follow,b in itertools.product([0,1],[0,1],[0,1]):
  rows.append(p.sequence({**base,'slow':slow,'follow':follow,'argument_b':b,'targets':[[160,260],None,[170,250],[100,100]]}))
 # One factory may fail while later factories still succeed; flag+0x46 matters.
 for slow,names in itertools.product([0,1],[['PoisonBubbleExplode','GooBubbleExplode'],['PoisonBubbleExplodeSpray','GooBubbleExplodeSpray'],['PoisonBubbleTrail','GooBubbleTrail'],['PoisonBubbleStars','GooBubbleStars']]):
  rows.append(p.sequence({**base,'slow':slow,'null_names':names}))
 # Full original inactive-bubble particle traversal: pre-update deletion,
 # first-release bit polarity, disable=0 fallback and callback-zero next pass.
 for count,first,disable,dt,flag in itertools.product([-1,0,2],[0,1,2],[0,6],[0,30],[0,2]):
  rows.append(p.sequence({**base,'deltas':[dt,dt],'factory_null':True,'supplied_flags':[flag,1,1,0],'supplied_roots':[{'count':count,'first':first,'disable':disable},{'count':0,'first':0,'disable':6},{'count':2,'first':1,'disable':6}],'particle_counts':[0]}))
 # Exact lift/dive boundary sizes, zero/large/negative steps and one-bit flags.
 for dt,flags in itertools.product([-.001,0,.001,499.999,500,500.001,600,1000],[[1,0,1,1],[1,1,1,1],[2,0,1,1],[3,1,2,2]]):
  rows.append(p.sequence({**base,'deltas':[dt,30,30],'supplied_flags':flags}))
 assert hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA
 report={'method':__doc__,'original_sha256':EXPECTED_SHA,'original_file_and_full_selected_bodies_unchanged':True,'bodies':{hex(a):{'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for a,b in p.bodies.items()},'sequences':rows,'scope':'Supplied contexts/callbacks incl texture headers from original requested dimensions; original Render records ordered draw calls, not pixels/GPU. No game or runtime change.'}
 out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'sequences':len(rows),'frames':sum(len(r['frames']) for r in rows),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}))
if __name__=='__main__':main()
