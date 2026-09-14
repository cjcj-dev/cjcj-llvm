#!/usr/bin/env python3
import pathlib,re,json,sys
root=pathlib.Path('/root/sym_cjcj_llvm_1_implement_r5668195885')
results=[]
for arm in ['baseline','green','producer','consumer','restored']:
 for level in ['O0','O2']:
  d=root/arm/'replay'/level
  assert (d/'compile.rc').read_text().strip()=='0'
  assert (d/'disassembly.rc').read_text().strip()=='0'
  expected={};atomic={}
  for f in (d/'temps').glob('*.opt.ll'):
   name=None
   for n,line in enumerate(f.read_text().splitlines(),1):
    m=re.match(r'define .*?@("[^"]+"|[^ (]+)\(',line)
    if m: name=m.group(1).strip('"')
    if name and re.search(r'call.*@llvm.cj.gcwrite.static.ref\(',line):
     expected.setdefault(name,[]).append(f'{f}:{n}')
    if name and re.search(r'call.*@llvm.cj.atomic.store\(',line):
     atomic.setdefault(name,[]).append(f'{f}:{n}')
    if line=='}':name=None
  text=(d/'disassembly.txt').read_text()
  chunks=re.split(r'^([0-9a-f]+) <(.+)>:\n',text,flags=re.M)
  funcs={chunks[i+1]:chunks[i+2] for i in range(1,len(chunks),3)}
  rows=[]
  snippets=d/'checked-functions';snippets.mkdir(exist_ok=True)
  for index,(name,anchors) in enumerate(expected.items()):
   body=funcs.get(name,'')
   calls=len(re.findall(r'<CJ_MCC_WriteStaticRef(?:@plt)?>',body))
   guards=re.findall(r'[^\n]*\bcmp\s+\$0x[89],[^\n]*',body)
   passed=bool(body) and calls==len(anchors) and not guards
   (snippets/f'{index}.asm').write_text(name+'\n'+body)
   rows.append(dict(function=name,ir_sites=anchors,expected=len(anchors),runtime_calls=calls,phase_compares=guards,passed=passed,assembly=str(snippets/f'{index}.asm')))
  # The public atomic operation may remain an out-of-line std.sync method at O0.
  starts=list(atomic) or [name for name in funcs if 'replaceAtomic' in name]
  def trace(name,path):
   if name.startswith('CJ_MCC_AtomicWriteReference'): return path+[name]
   if len(path)>8 or name in path:return None
   for callee in re.findall(r'\b(?:callq?|jmpq?)\s+[^\n]*<(.*)>',funcs.get(name,'')):
    found=trace(callee,path+[name])
    if found:return found
   return None
  paths={name:trace(name,[]) for name in starts}
  result=dict(arm=arm,level=level,static=rows,atomic_paths=paths,static_pass=bool(rows) and all(r['passed'] for r in rows),atomic_pass=bool(paths) and all(paths.values()))
  (d/'checks.json').write_text(json.dumps(result,indent=2)+'\n')
  (d/'checks.rc').write_text(('0' if result['static_pass'] and result['atomic_pass'] else '1')+'\n')
  results.append(result)
(root/'replay-checks.json').write_text(json.dumps(results,indent=2)+'\n')
for r in results:print(r['arm'],r['level'],'static',r['static_pass'],'atomic',r['atomic_pass'],'functions',len(r['static']))
