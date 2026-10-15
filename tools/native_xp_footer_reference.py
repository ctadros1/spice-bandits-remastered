"""Original MenuBottomView XP rounding, format requests and bar width.

Session/UI/data identities, NSString formatting, CGRect access and roundf
are explicit stubs. Original arithmetic, branches, format requests, final
frame width and promotion visibility execute; UIKit pixels do not.
"""
from native_creep_reference import *
import math

class FooterProbe(Probe):
    def __init__(self):
        super().__init__()
        symbol=next(s for s in json.load(open('original/analysis/decrypted-symbols.json')) if s['name']=='_OBJC_IVAR_$_MenuBottomView.defaultXPBarWidth' and s['value'])
        self.width_offset=struct.unpack('<I',self.u.mem_read(symbol['value'],4))[0]

    def cf(self,address):
        if address==E+0x1000:return 'stub'
        return self.string(struct.unpack('<I',self.u.mem_read(address+8,4))[0])

    def hook(self,u,address,size,data):
        if address==0x36c82c:
            value=struct.unpack('<f',I(u.reg_read(UC_ARM_REG_R0)))[0]
            self.ret(BITS(math.copysign(math.floor(abs(value)+0.5),value)));return
        if address==0x36be9c:
            u.mem_write(u.reg_read(UC_ARM_REG_R0),F(0)+F(0)+F(self.width)+F(14));self.ret();return
        if address==0x36be6c:
            receiver,selector,arg,arg3=[u.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3)]
            name=self.string(selector)
            if name=='isHidden':self.ret(0);return
            if name=='deviceType':self.ret(2);return
            if name=='objectForKey:':
                key=self.cf(arg)
                pointer=E+0x4000+len(self.number_ids)*16;self.number_ids[pointer]=key
                self.ret(pointer);return
            if name=='floatValue':self.ret(BITS(self.values.get(self.number_ids[receiver],0)));return
            if name=='intValue':
                value=int(self.values.get(self.number_ids[receiver],0));self.result['level_reads'].append(value);self.ret(value);return
            if name=='frameWidth':self.ret(BITS(self.width));return
            if name=='playerXpStatus':self.ret(E+0x5000);return
            if name=='offlineLevelUpView':self.ret(E+0x5100);return
            if name=='setHidden:' and receiver==E+0x5100:self.result['promotion_hidden']=bool(arg)
            if name=='setFrame:':
                self.result['bar_width']=struct.unpack('<f',u.mem_read(u.reg_read(UC_ARM_REG_SP),4))[0]
            if name=='stringWithFormat:':
                format=self.cf(arg)
                if '%' in format and 'f' in format:
                    amount=struct.unpack('<d',u.mem_read(u.reg_read(UC_ARM_REG_SP),8))[0]
                    self.result['formats'].append({'format':format,'amount':amount})
            self.ret(E+0x1000);return
        super().hook(u,address,size,data)

    def run(self,xp,remaining,lower,level,width):
        self.u.mem_write(E,bytes(0x6000));self.u.mem_write(E+self.width_offset,F(width))
        self.width=width or 82;self.values={'xppoints':xp,'tonextlevel':remaining,'levelpoints':lower,'level':level};self.number_ids={}
        self.result={'formats':[],'level_reads':[]}
        self.u.reg_write(UC_ARM_REG_SP,STACK-64);self.u.reg_write(UC_ARM_REG_LR,END|1)
        self.u.reg_write(UC_ARM_REG_R0,E);self.u.reg_write(UC_ARM_REG_R1,0);self.u.reg_write(UC_ARM_REG_R2,E+0x1000)
        self.u.emu_start(0x512a9,END,count=100000);assert self.u.reg_read(UC_ARM_REG_PC)==END
        return self.result

p=FooterProbe();cases=[]
for xp,remaining,lower,level in [(0,10,0,1),(8.1,1.9,0,1),(9.49,0.51,0,1),(9.5,0.5,0,1),(10,0,0,1),(10,30,10,2),(53286.7,73,50000,73),(999.49,100,0,1),(999.5,100,0,1),(1000,100,0,1),(999999.5,100,0,1),(1000000,100,0,1)]:
    for width in (0,82,120):cases.append({'xp':xp,'remaining':remaining,'lower':lower,'level':level,'width':width,'result':p.run(xp,remaining,lower,level,width)})
record={'method':__doc__,'original_sha256':EXPECTED_SHA,'cases':cases,'original_unchanged':hashlib.sha256(EXE.read_bytes()).hexdigest()==EXPECTED_SHA}
Path('tests/fixtures/native-xp-footer-reference.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'cases':len(cases),'sample':cases[3],'original_unchanged':record['original_unchanged']}))
