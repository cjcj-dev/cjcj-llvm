#!/usr/bin/env python3
"""Sequential P0 allowlist with one pinned authorization ledger and receipts.

A ledger is provisioned once by the authorizer, never created/reset by this
runner. Hold its nonblocking lock through execution. Reserve consumption before
launch; an interrupted batch remains stopped. Receipts bind every continuation.
"""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
import resource
import subprocess
import time
from pathlib import Path


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write(path, value):
    # Atomic replacement; callers hold the stable sibling lock inode.
    tmp = path.with_name(path.name + '.new')
    with tmp.open('w') as f:
        f.write(json.dumps(value, indent=2) + '\n')
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--plan', required=True)
    p.add_argument('--plan-sha256', required=True)
    p.add_argument('--authorization', required=True)
    p.add_argument('--authorization-sha256', required=True)
    p.add_argument('--out', required=True)
    a = p.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=False)
    records, state, lock, ledger = [], None, None, None
    state_bound = False
    envelope = {'started_utc': utc(), 'plan_sha256': a.plan_sha256,
                'runner_sha256': sha(__file__), 'status': 'STOPPED',
                'reason': 'preflight incomplete', 'records': records,
                'subprocesses_started': 0,
                'budget_counts_semantics': 'conservative charged slots; object reserves checker plus objdump'}
    start = time.monotonic()
    def save():
        envelope['wall'] = time.monotonic() - start
        write(out / 'records.json', envelope)
    try:
        require(sha(a.authorization) == a.authorization_sha256, 'authorization hash differs')
        auth = json.loads(Path(a.authorization).read_text())
        envelope.update(execution=auth['execution'],
                        authorization_sha256=a.authorization_sha256,
                        deadline_utc=auth['deadline_utc'])
        ledger = Path(auth['ledger'])
        require(ledger.is_absolute() and ledger.resolve() == ledger and not ledger.is_symlink(), 'ledger path differs')
        lock = ledger.with_name(ledger.name + '.lock').open('a')
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            lock.close()
            lock = None
            raise RuntimeError('chain already running')
        # Missing state is an error, never an invitation to start a new chain.
        state = json.loads(ledger.read_text())
        require(state['authorization_sha256'] == a.authorization_sha256, 'ledger authorization differs')
        require(state['execution'] == auth['execution'], 'ledger execution differs')
        state_bound = True
        require(0 <= auth['limits']['syntax'] <= 36 and 0 <= auth['limits']['object'] <= 8
                and 0 <= auth['limits']['subprocesses'] <= 52, 'authorization exceeds P0 ceiling')
        require(state['status'] == 'SUCCESS', 'chain stopped')
        require(sha(a.plan) == a.plan_sha256, 'plan hash differs')
        plan = json.loads(Path(a.plan).read_text())
        envelope.update(execution=auth['execution'], source_manifest=plan['source_manifest'],
                        authorization_sha256=a.authorization_sha256,
                        deadline_utc=auth['deadline_utc'])
        require(plan['execution'] == auth['execution'], 'execution identity differs')
        require(plan['authorization_sha256'] == a.authorization_sha256, 'plan authorization differs')
        require(sha(__file__) == auth['runner_sha256'], 'runner identity differs')
        require(all(auth['execution'].get(k) not in (None, '', 'UNKNOWN')
                    for k in ('lane', 'role', 'run', 'session', 'candidate')), 'execution identity unknown')
        deadline = datetime.datetime.fromisoformat(auth['deadline_utc'])
        require(deadline.tzinfo is not None, 'deadline timezone missing')
        require(datetime.datetime.now(datetime.timezone.utc) < deadline, 'absolute deadline reached')
        if state['last_receipt'] is None:
            require(plan['prior_receipt'] is None, 'unexpected prior receipt')
        else:
            prior = plan['prior_receipt']
            require(prior is not None, 'prior receipt missing')
            require(prior == state['last_receipt'], 'prior receipt binding differs')
            require(sha(prior['path']) == prior['sha256'], 'prior receipt hash differs')
            receipt = json.loads(Path(prior['path']).read_text())
            require(receipt['execution'] == auth['execution'], 'prior execution differs')
            require(receipt['status'] == 'SUCCESS', 'prior receipt stopped')
            require(receipt['cumulative_counts'] == state['counts'], 'prior counts differ')
        identities = {x['path']: x['sha256'] for x in plan['identities']}
        for path, digest in identities.items():
            require(sha(path) == digest, 'identity differs: ' + path)
        demand = {'syntax': 0, 'object': 0, 'subprocesses': 0}
        for c in plan['commands']:
            kind, argv = c['kind'], c['argv']
            require(kind in ('syntax', 'object'), 'unknown command kind')
            if kind == 'syntax':
                require(argv[0] == plan['llvm_as'] and len(argv) == 4 and argv[2:] == ['-o', os.devnull], 'syntax argv differs')
                paths = argv[:2]
                children = 1
            else:
                require(argv[:2] == ['python3', plan['checker']], 'object argv differs')
                paths = [plan['checker']]
                # Checker itself plus its one objdump invocation.
                children = 2
            require(all(path in identities for path in paths), 'command identity missing')
            demand[kind] += 1
            demand['subprocesses'] += children
            records.append({'id': c['id'], 'kind': kind, 'status': 'NOT_RUN', 'reason': 'not yet started', 'launched': False})
        require(len({r['id'] for r in records}) == len(records), 'duplicate command id')
        for kind, count in demand.items():
            require(state['counts'][kind] + count <= auth['limits'][kind], 'cumulative budget exceeded: ' + kind)
        # Reserve this entire batch before spawning. An interruption cannot
        # recover a SUCCESS ledger or reuse already reserved consumption.
        state['status'] = 'STOPPED'
        state['reserved_counts'] = {k: state['counts'][k] + demand[k] for k in demand}
        write(ledger, state)
        save()
        for c, r in zip(plan['commands'], records):
            require(datetime.datetime.now(datetime.timezone.utc) < deadline, 'absolute deadline reached')
            r.update(status='RUNNING', reason='command running', launched=True, started_utc=utc(), argv=c['argv'])
            state['counts'][c['kind']] += 1
            state['counts']['subprocesses'] += 1 if c['kind'] == 'syntax' else 2
            write(ledger, state)
            envelope['subprocesses_started'] += 1
            save()
            proc = subprocess.run(c['argv'], capture_output=True, text=True,
                                  timeout=min(30, (deadline - datetime.datetime.now(datetime.timezone.utc)).total_seconds()))
            for suffix, value in (('stdout', proc.stdout), ('stderr', proc.stderr), ('rc', str(proc.returncode) + '\n')):
                (out / (c['id'] + '.' + suffix)).write_text(value)
            r.update(rc=proc.returncode, finished_utc=utc())
            if c['kind'] == 'object':
                # Account a nested launch even when its target result fails.
                r['nested_subprocesses_started'] = 'UNKNOWN'
                result = json.loads(Path(c['result']).read_text())
                r['nested_subprocesses_started'] = int('objdump_command' in result)
                envelope['subprocesses_started'] += r['nested_subprocesses_started']
            require(proc.returncode == c['expected_rc'], 'unexpected rc: ' + c['id'])
            if c['kind'] == 'object':
                failed = [x['axis'] for x in result.get('assertions', []) if not x['passed']]
                require(result.get('status') in ('PASS', 'FAIL') and failed == c['expected_failed_axes'], 'target failure axes differ: ' + c['id'])
                require(all(x['reached'] for x in result['assertions']), 'target assertion not reached')
                r['assertions'] = result['assertions']
                # The checker reports actual nested invocation evidence.
                require(result['objdump_rc'] == 0, 'objdump failed')
            r.update(status='EXPECTED', reason='expected result observed')
            save()
        for item in plan['original_objects']:
            require(sha(item['path']) == item['sha256'], 'original object changed')
        envelope.update(status='SUCCESS', reason='all expected results observed', cumulative_counts=state['counts'])
        save()
        state.update(status='SUCCESS', last_receipt={'path': str((out / 'records.json').resolve()), 'sha256': sha(out / 'records.json')})
        write(ledger, state)
        print('SUCCESS', flush=True)
        return 0
    except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as e:
        reason = str(e)
        for r in records:
            if r['status'] == 'RUNNING':
                r.update(status='UNEXPECTED', reason=reason)
            elif r['status'] == 'NOT_RUN':
                r['reason'] = 'chain stop: ' + reason
        envelope.update(status='STOPPED', reason=reason)
        if state_bound and lock is not None:
            state['status'] = 'STOPPED'
            write(ledger, state)
            envelope['cumulative_counts'] = state['counts']
        (out / 'STOP.txt').write_text(reason + '\n')
        save()
        print('STOP', reason, flush=True)
        return 1
    finally:
        if lock is not None:
            lock.close()


if __name__ == '__main__':
    raise SystemExit(main())
