from pathlib import Path
import json,hashlib,subprocess
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149')
def load(p): return json.loads((r/p).read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
facts={'lit':load('lit-comparison.json'),'observations':{},'managed':{},'link_map':load('link-map-identity.json')}
for arm in ['baseline','green','consumer','producer','restored']:
 rows=load(f'observations/{arm}/results.json')['rows']
 facts['observations'][arm]={'n':len(rows),'llc_failures':[x for x in rows if x['llc_rc']!=0],'check_failures':[{'name':x['name'],'level':x['level']} for x in rows if x['check_rc']!=0],'identity':load(f'observations/{arm}/identity.json'),'range_loads':{x['name']+':'+x['level']:x['range_loads'] for x in rows},'mask_reads':{x['name']+':'+x['level']:x['mask_reads'] for x in rows}}
for arm in ['baseline','candidate']:
 facts['managed'][arm]={'identity':load(f'managed/{arm}/run-identity.json'),'runs':load(f'managed/{arm}/run-results.json'),'uptime_before':(r/f'managed/{arm}/uptime-before.txt').read_text(),'uptime_after':(r/f'managed/{arm}/uptime-after.txt').read_text(),'ref_calls':(r/f'managed/{arm}/ref-calls.txt').read_text()}
 for file in (r/f'managed/{arm}/temps').glob('*.opt.bc.ll'):
  for line in file.read_text().splitlines():
   if 'i64 3736' in line: facts['managed'][arm].setdefault('folded_result',[]).append(str(file)+': '+line)
facts['final_source_sha256']=sha(r/'candidate-src/llvm/lib/CodeGen/CJBarrierLowering.cpp')
facts['product_sha256']={arm:sha(r/arm/'bin/llc') for arm in ['baseline','green','consumer','producer','candidate']}
facts['unchanged_filecheck']=len(set(facts['observations'][a]['identity']['filecheck_sha256'] for a in facts['observations']))==1
facts['green_equals_restored']=facts['product_sha256']['green']==facts['product_sha256']['candidate']
facts['cuts_differ']=all(facts['product_sha256'][a]!=facts['product_sha256']['green'] for a in ['consumer','producer'])
facts['source_inputs_identical']=len({json.dumps(facts['observations'][a]['identity']['input_sha256'],sort_keys=True) for a in facts['observations']})==1
(r/'validation-summary.json').write_text(json.dumps(facts,indent=2))
print('green_equals_restored',facts['green_equals_restored'],'cuts_differ',facts['cuts_differ'],'same_FileCheck',facts['unchanged_filecheck'],'same_inputs',facts['source_inputs_identical'])
