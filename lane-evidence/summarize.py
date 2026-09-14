import pathlib,json,collections
root=pathlib.Path('/root/sym_cjcj_llvm_1_implement_r5668195885')
for arm in ['green','producer','consumer','restored']:
 p=root/arm
 print(arm)
 for name in ['rebuild.rc','lit.rc','test-wall.txt','rebuild-wall.txt','static-O0-ir-check.rc','static-O2-ir-check.rc','static-O0-asm-check.rc','static-O2-asm-check.rc']:
  print(name,(p/name).read_text().strip())
 d=json.loads((p/'lit.json').read_text())
 print(collections.Counter(t['code'] for t in d['tests']))
 for t in d['tests']:
  if 'static-' in t['name']: print(t['name'],t['code'],t.get('output','')[-2400:])
 for level in ['O0','O2']:
  print(level,(p/'replay'/level/'compile.rc').read_text().strip())
 print('identity', (p/'product.sha256').read_text())
for d in json.loads((root/'replay-checks.json').read_text()):
 print('REPLAY',d['arm'],d['level'],len(d['static']),d['static_pass'],d['atomic_pass'])
for name in ['build-uptime-before.txt','build-uptime-after.txt','rebuild-uptime-before.txt','rebuild-uptime-after.txt']:
 print(name,(root/name).read_text().strip())
