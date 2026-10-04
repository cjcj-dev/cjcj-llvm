#!/usr/bin/env python3
"""Execute only a prehashed P0 allowlist, sequentially, with a global stop.

No retries, no codegen, no repair after failure. The plan and all records are
persisted before launch; a stopped tail is explicitly NOT_RUN. Run via box/wf.
"""
import argparse
import datetime
import hashlib
import json
import os
import resource
import subprocess
import time
from pathlib import Path

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--plan',required=True)
    p.add_argument('--plan-sha256',required=True)
    p.add_argument('--out',required=True)
    a = p.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out = Path(a.out)
    out.mkdir(parents=True,exist_ok=True)
    plan = json.loads(Path(a.plan).read_text())
    records = [{'id':r['id'],'status':'NOT_RUN','reason':'not yet started'} for r in plan['commands']]
    stopped = False
    start = time.monotonic()
    def save():
        (out/'records.json').write_text(json.dumps({'records':records,'stopped':stopped,'wall':time.monotonic()-start,
            'counts':{kind:sum(r.get('launched',False) and r.get('kind') == kind for r in records) for kind in ('syntax','object')}},indent=2)+'\n')
    save()
    try:
        assert sha(a.plan) == a.plan_sha256, 'plan hash differs'
        assert sum(c['kind'] == 'syntax' for c in plan['commands']) <= 36
        assert sum(c['kind'] == 'object' for c in plan['commands']) <= 8
        # Check all declared tools, scripts, and original objects before any
        # launch. Missing prerequisites stop this whole frozen plan.
        for item in plan['identities']:
            assert sha(item['path']) == item['sha256'], 'identity differs: '+item['path']
        (out/'identity-status.json').write_text(json.dumps({'status':'VERIFIED','identities':plan['identities']},indent=2)+'\n')
        for i,c in enumerate(plan['commands']):
            if datetime.datetime.now(datetime.timezone.utc).isoformat() >= plan['deadline_utc']:
                raise RuntimeError('absolute deadline reached')
            argv = c['argv']
            if c['kind'] == 'syntax':
                assert argv[0] == plan['llvm_as'] and len(argv) == 4 and argv[2] == '-o' and argv[3] == os.devnull
            else:
                assert argv[:2] == ['python3',plan['checker']]
            r = records[i]
            r.update({'kind':c['kind'],'argv':argv,'status':'RUNNING','launched':True,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
            save()
            before = time.monotonic()
            proc = subprocess.run(argv,capture_output=True,text=True,timeout=30)
            (out/(c['id']+'.stdout')).write_text(proc.stdout)
            (out/(c['id']+'.stderr')).write_text(proc.stderr)
            (out/(c['id']+'.rc')).write_text(str(proc.returncode)+'\n')
            r.update({'rc':proc.returncode,'wall':time.monotonic()-before,'stdout':str(out/(c['id']+'.stdout')),'stderr':str(out/(c['id']+'.stderr'))})
            assert proc.returncode == c['expected_rc'], 'unexpected rc: '+c['id']
            if c['kind'] == 'object':
                result = json.loads(Path(c['result']).read_text())
                failed = [x['axis'] for x in result.get('assertions',[]) if not x['passed']]
                assert result.get('status') in ('PASS','FAIL') and failed == c['expected_failed_axes'], 'target not reached or failure axes differ: '+c['id']
                assert all(x['reached'] for x in result['assertions']), 'target assertion not reached'
                r['assertions'] = result['assertions']
            r['status'] = 'EXPECTED'
            save()
            print(c['id'], 'rc='+str(proc.returncode), 'wall='+str(round(r['wall'],3)),flush=True)
        for item in plan['original_objects']:
            assert sha(item['path']) == item['sha256'], 'original object changed'
        save()
        return 0
    except (AssertionError,RuntimeError,OSError,ValueError,subprocess.TimeoutExpired) as e:
        stopped = True
        for r in records:
            if r['status'] == 'RUNNING':
                r['status'] = 'UNEXPECTED'
            if r['status'] == 'NOT_RUN':
                r['reason'] = 'global stop: '+str(e)
        (out/'STOP.txt').write_text(str(e)+'\n')
        save()
        print('STOP',str(e),flush=True)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
