#!/usr/bin/env python3
"""One bounded integration control of the actual P0 runner; no LLVM tools.

Prepare the immutable scenario list before executing it once via box. Unexpected
results abort the whole suite. No subprocess mocking or runner bypass switches.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def put(path, obj):
    with path.open('x') as f:
        f.write(json.dumps(obj, indent=2) + '\n')


SCENARIOS = [
    ('A1', 'A', 0, 1, 'SUCCESS', None, 0),
    ('A2', 'A', 0, 1, 'SUCCESS', None, 0),
    ('B1', 'B', 1, 1, 'unexpected rc: B1-0', None, 7),
    ('B2', 'B', 1, 0, 'chain stopped', 'delete-stop', 0),
    ('C1', 'C', 0, 1, 'SUCCESS', None, 0),
    ('C2', 'C', 1, 0, 'cumulative budget exceeded: syntax', None, 0),
    ('D1', 'D', 0, 1, 'SUCCESS', None, 0),
    ('D2', 'D', 1, 0, 'No such file or directory', 'missing', 0),
    ('E1', 'E', 0, 1, 'SUCCESS', None, 0),
    ('E2', 'E', 1, 0, 'prior receipt hash differs', 'corrupt', 0),
    ('F1', 'F', 0, 1, 'SUCCESS', None, 0),
    ('F2', 'F', 1, 0, 'execution identity differs', 'identity', 0),
]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--root', required=True)
    p.add_argument('--identity', required=True)
    p.add_argument('--prepare', action='store_true')
    p.add_argument('--freeze-sha256')
    a = p.parse_args()
    root = Path(a.root).resolve()
    runner = Path(__file__).with_name('run_plan.py').resolve()
    if a.prepare:
        root.mkdir(parents=True, exist_ok=False)
        identity = json.loads(Path(a.identity).read_text())
        child = root / 'harmless.py'
        child.write_text('#!/usr/bin/python3\nimport json,sys\nfrom pathlib import Path\nx=json.loads(Path(sys.argv[1]).read_text())\nwith Path(x["marker"]).open("a") as f: f.write(x["id"]+"\\n")\nsys.exit(x["rc"])\n')
        child.chmod(0o755)
        cases = []
        for name, chain, rc, launches, reason, mutation, childrc in SCENARIOS:
            folder = root / chain
            folder.mkdir(exist_ok=True)
            authfile = folder / 'authorization.json'
            if not authfile.exists():
                auth = {'execution': identity, 'runner_sha256': sha(runner),
                        'ledger': str(folder / 'ledger.json'),
                        'deadline_utc': identity['deadline_utc'],
                        'limits': {'syntax': 2 if chain in ('A', 'B') else 1,
                                   'object': 0, 'subprocesses': 2 if chain in ('A', 'B') else 1}}
                put(authfile, auth)
                put(folder / 'ledger.json', {'authorization_sha256': sha(authfile),
                    'execution': identity, 'status': 'SUCCESS', 'last_receipt': None,
                    'counts': {'syntax': 0, 'object': 0, 'subprocesses': 0}})
            inputs = []
            for i in range(2 if name == 'B1' else 1):
                path = folder / (name + '-' + str(i) + '.json')
                put(path, {'marker': str(root / 'calls.txt'), 'id': name + '-' + str(i), 'rc': childrc})
                inputs.append({'path': str(path), 'sha256': sha(path)})
            cases.append({'id': name, 'chain': chain, 'expected_runner_rc': rc,
                          'expected_subprocesses': launches, 'expected_reason': reason,
                          'mutation': mutation, 'inputs': inputs,
                          'runner_argv': [sys.executable, str(runner), '--plan', str(folder / (name + '-plan.json')),
                                          '--plan-sha256', '<hash of frozen plan with prior immutable receipt>',
                                          '--authorization', str(authfile), '--authorization-sha256', sha(authfile),
                                          '--out', str(folder / (name + '-out'))],
                          'child_argv': [[str(child), x['path'], '-o', os.devnull] for x in inputs]})
        put(root / 'frozen-scenarios.json', {'execution': identity, 'runner_sha256': sha(runner),
             'suite_sha256': sha(__file__), 'child_sha256': sha(child),
             'runner_limit': 12, 'child_limit': 8, 'cases': cases,
             'source_manifest': {'lane': 'inherited-plan-control', 'role': 'synthesize',
                                 'created_at': 'UNKNOWN'}})
        print(sha(root / 'frozen-scenarios.json'))
        return
    assert sha(root / 'frozen-scenarios.json') == a.freeze_sha256
    frozen = json.loads((root / 'frozen-scenarios.json').read_text())
    assert sha(__file__) == frozen['suite_sha256'] and sha(runner) == frozen['runner_sha256']
    assert len(frozen['cases']) <= 12 and sum(c['expected_subprocesses'] for c in frozen['cases']) <= 8
    # This durable marker makes a second suite invocation fail before any runner.
    (root / 'EXECUTED').open('x').close()
    trace = []
    def marks():
        return (root / 'calls.txt').read_text().splitlines() if (root / 'calls.txt').exists() else []
    for c in frozen['cases']:
        folder = root / c['chain']
        state = json.loads((folder / 'ledger.json').read_text())
        prior = state['last_receipt']
        if c['mutation'] == 'delete-stop':
            (folder / 'B1-out' / 'STOP.txt').unlink()
        if c['mutation'] == 'missing':
            Path(prior['path']).rename(folder / 'retained-prior.json')
        if c['mutation'] == 'corrupt':
            old = Path(prior['path']).read_bytes()
            (folder / 'retained-prior.json').write_bytes(old)
            Path(prior['path']).write_bytes(old + b' ')
        identity = dict(frozen['execution'])
        if c['mutation'] == 'identity':
            identity['session'] = 'conflicting-session'
        plan = {'execution': identity, 'source_manifest': frozen['source_manifest'],
                'authorization_sha256': sha(folder / 'authorization.json'), 'prior_receipt': prior,
                'llvm_as': str(root / 'harmless.py'), 'checker': 'UNUSED',
                'identities': [{'path': str(root / 'harmless.py'), 'sha256': frozen['child_sha256']}] + c['inputs'],
                'commands': [{'id': Path(x['path']).stem, 'kind': 'syntax', 'argv': argv, 'expected_rc': 0}
                             for x, argv in zip(c['inputs'], c['child_argv'])], 'original_objects': []}
        planfile = folder / (c['id'] + '-plan.json')
        put(planfile, plan)
        argv = list(c['runner_argv'])
        argv[5] = sha(planfile)
        before = marks()
        proc = subprocess.run(argv, capture_output=True, text=True)
        (root / (c['id'] + '.stdout')).write_text(proc.stdout)
        (root / (c['id'] + '.stderr')).write_text(proc.stderr)
        (root / (c['id'] + '.rc')).write_text(str(proc.returncode) + '\n')
        after = marks()
        receiptfile = folder / (c['id'] + '-out') / 'records.json'
        receipt = json.loads(receiptfile.read_text())
        row = {'id': c['id'], 'argv': argv, 'runner_rc': proc.returncode,
               'new_calls': after[len(before):], 'plan_sha256': sha(planfile),
               'receipt_sha256': sha(receiptfile), 'reason': receipt['reason']}
        trace.append(row)
        (root / 'trace.json').write_text(json.dumps(trace, indent=2) + '\n')
        assert proc.returncode == c['expected_runner_rc'], row
        assert len(after) - len(before) == c['expected_subprocesses'], row
        assert c['expected_reason'] in proc.stdout, row
        assert receipt['subprocesses_started'] == c['expected_subprocesses'], row
        if proc.returncode == 0:
            assert receipt['execution'] == frozen['execution']
            assert receipt['source_manifest'] == frozen['source_manifest']
            assert all(r['reason'] == 'expected result observed' and r['rc'] == 0 for r in receipt['records'])
        assert len(trace) <= 12 and len(after) <= 8
        print(c['id'], 'runner_rc=' + str(proc.returncode), 'children=' + str(len(after) - len(before)), flush=True)
    put(root / 'suite-result.json', {'status': 'EXPECTED', 'runner_starts': len(trace),
                                    'child_starts': len(marks()), 'freeze_sha256': a.freeze_sha256})


if __name__ == '__main__':
    main()
