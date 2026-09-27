# Inspect the actual x86-64 ET_REL object's Cangjie compressed stack map.
# The function's preceding PC-relative descriptor points to methodinfo, whose
# first relocation points to the stack map. Call relocations identify the exact
# return PC; no expected offsets or synthetic stack map records are supplied.
# Format: llvm/lib/CodeGen/StackMaps.cpp:1644-1710 (stack-grow enabled).
import struct, sys, json, hashlib
from pathlib import Path
p=Path(sys.argv[1]); b=p.read_bytes(); fn=sys.argv[2] if len(sys.argv)>2 else '_CNat4LibC13mallocCStringHRNat6StringE'
assert b[:6]==b'\x7fELF\x02\x01'
h=struct.unpack_from('<HHIQQQIHHHHHH',b,16); shoff=h[5]; shsize,shnum,shstr=h[10:13]
sects=[struct.unpack_from('<IIQQQQIIQQ',b,shoff+i*shsize) for i in range(shnum)]
def data(i):
 s=sects[i]; return b[s[4]:s[4]+s[5]]
def string(buf,off): return buf[off:buf.find(b'\0',off)].decode()
names=[string(data(shstr),s[0]) for s in sects]
syms={}
for i,s in enumerate(sects):
 if s[1]==2:
  st=data(i); strings=data(s[6]); tab=[]
  for off in range(0,len(st),s[9]):
   name,info,other,section,value,size=struct.unpack_from('<IBBHQQ',st,off)
   tab.append((string(strings,name),section,value,size))
  syms[i]=tab
symbol=next(v for tab in syms.values() for v in tab if v[0]==fn)
_,sec,start,size=symbol
relocs={}
for i,s in enumerate(sects):
 if s[1]==4:
  for off in range(0,s[5],s[9]):
   pos,info,add=struct.unpack_from('<QQq',data(i),off)
   sym=syms[s[6]][info>>32]
   relocs[s[7],pos]=(sym,add,info&0xffffffff)
def target(section,pos):
 sym,add,typ=relocs[section,pos]
 return sym[1],sym[2]+add
# A function with no safepoint-carrying call has no stack map at all; that is
# exactly the leaf-Acquire regression this decodes, so report it as no root
# rather than failing to walk the record.
rows=[]; regs=[]
if (sec,start-4) in relocs:
    md,mdpos=target(sec,start-4)
    if (md,mdpos) in relocs:
        sm,smpos=target(md,mdpos)
        bits=int.from_bytes(data(sm)[smpos:], 'little'); cursor=0
        def take(n):
            global cursor
            v=(bits>>cursor)&((1<<n)-1); cursor+=n; return v
        def var():
            t=take(4); return t if t<=11 else take((t-11)*8)
        stack,fmt,pro=var(),var(),var(); offsets=[var() for i in range(32) if pro&(1<<i)]
        cols=8+(2 if fmt&2 else 0)
        hdr=[var() for _ in range(cols)]; take(hdr[-1])
        rows=[[take(32)]+[take(n) for n in hdr[1:-1]] for _ in range(hdr[0])]
        rn,rw=var(),var(); regs=[take(rw) for _ in range(rn)]
stack=0; fmt=0; pro=0; hdr=[0]*9
calls=[]
for (section,pos),(sym,add,typ) in relocs.items():
 if section==sec and start<=pos<start+size and sym[0] in ('CJ_MCC_AcquireRawData','CJ_MCC_ReleaseRawData'):
  ret=pos+4-start
  matches=[r for r in rows if r[0]==ret]
  calls.append(dict(callee=sym[0],return_offset=ret,rows=matches,reg_masks=[regs[r[1]-1] if r[1] else 0 for r in matches]))
out=dict(file=str(p),sha256=hashlib.sha256(b).hexdigest(),function=fn,size=size,stack=stack,format=fmt,prologue=pro,header=hdr,rows=rows,regs=regs,calls=calls)
print(json.dumps(out,indent=2))
acqs=[c for c in calls if c['callee']=='CJ_MCC_AcquireRawData']
ok=bool(acqs) and all(c['rows'] and any(mask or row[2] for mask,row in zip(c['reg_masks'],c['rows'])) for c in acqs)
print('ACQUIRE_RETURN_ROOT='+str(ok))
sys.exit(0 if ok else 1)
