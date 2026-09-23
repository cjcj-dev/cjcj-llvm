from pathlib import Path
import json,collections
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149')
def tests(p): return {t['name']:t for t in json.loads(p.read_text())['tests']}
def bad(t): return t['code'] not in ('PASS','UNSUPPORTED','XFAIL')
def brief(d): return dict(collections.Counter(t['code'] for t in d.values()))
baseline=tests(r/'baseline-lit.json');green=tests(r/'green/candidate-lit.json')
result={'baseline':brief(baseline),'green':brief(green),'same_input_names':sorted(baseline)==sorted(green),'candidate_only':[n for n in green if bad(green[n]) and not bad(baseline[n])], 'baseline_only':[n for n in baseline if bad(baseline[n]) and not bad(green[n])], 'new_tests':{n:t['code'] for n,t in green.items() if '/heap-domain-' in n},'common_failures':[n for n in green if bad(green[n]) and bad(baseline[n])]}
for arm in ['consumer','producer','restored']:
 p=r/(arm+'-lit.json')
 if p.exists():
  d=tests(p)
  result[arm]={'counts':brief(d),'same_test_names':sorted(d)==sorted(green),'new_failures':[n for n in d if bad(d[n]) and not bad(green[n])],'changed_status':{n:[green[n]['code'],d[n]['code']] for n in d if green[n]['code']!=d[n]['code']}}
(r/'lit-comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='new_tests'},indent=2))
