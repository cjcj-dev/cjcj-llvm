#!/usr/bin/env python3
"""Link measured llc objects with Apple's linker and check each final address."""
import base64
import concurrent.futures
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = Path('funcdesc-map-results').resolve()
OUT.mkdir(exist_ok=True)
CPU = 'arm64' if platform.machine() in ('arm64', 'aarch64') else 'x86_64'
manifest = json.loads((HERE / 'objects.json').read_text())
repo = HERE.parents[2]
for name, digest in manifest['sources'].items():
    if hashlib.sha256((repo / name).read_bytes()).hexdigest() != digest:
        raise RuntimeError('source identity mismatch: ' + name)
subprocess.run(['uptime'], stdout=(OUT / 'uptime-before.log').open('w'), check=True)


def run(arm):
    folder = OUT / arm
    folder.mkdir(exist_ok=True)
    objects = []
    for row in manifest['objects']:
        if row['cpu'] != CPU or row['arm'] != arm or row['platform'] != 'macos':
            continue
        data = base64.b64decode(row['base64'], validate=True)
        if hashlib.sha256(data).hexdigest() != row['sha256']:
            raise RuntimeError('object identity mismatch')
        path = folder / (row['module'] + '.o')
        path.write_bytes(data)
        objects.append(path)
    if len(objects) != 2:
        raise RuntimeError('expected two real llc modules')
    (folder / 'exports.txt').write_text('\n'.join('_map_' + x for x in ('first', 'init', 'second', 'leaf', 'plain')) + '\n')
    (folder / 'order.txt').write_text('_map_second\n_map_first\n')
    results = []
    for stripped in (False, True):
        name = 'strip' if stripped else 'all'
        dylib = folder / (name + '.dylib')
        cmd = ['clang', '-dynamiclib', '-arch', CPU, '-Wl,-undefined,dynamic_lookup',
               '-Wl,-no_fixup_chains', '-Wl,-install_name,@rpath/libfuncdesc-map.dylib', '-Wl,-order_file,' + str(folder / 'order.txt'),
               *map(str, objects), '-o', str(dylib)]
        if stripped:
            cmd += ['-Wl,-dead_strip', '-Wl,-exported_symbols_list,' + str(folder / 'exports.txt')]
        with (folder / (name + '-link.log')).open('w') as log:
            log.write(repr(cmd) + '\n'); log.flush()
            rc = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT).returncode
        if rc:
            results.append({'arm': arm, 'mode': name, 'link_rc': rc, 'target_executed': False})
            continue
        for tool, args in [('nm', ['-an']), ('otool', ['-l']), ('otool', ['-s', '__CJ_METADATA', '__cjfuncmap'])]:
            with (folder / (name + '-' + tool + '-' + args[0].lstrip('-') + '.log')).open('w') as log:
                subprocess.run([tool, *args, str(dylib)], stdout=log, stderr=subprocess.STDOUT)
        cmd = [sys.executable, str(HERE / 'check.py'), str(dylib)]
        if stripped:
            cmd.append('--dead-strip')
        check_run = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (folder / (name + '-check.log')).write_text(check_run.stdout)
        targets = [line.removeprefix('FUNC_MAP_TARGET ') for line in check_run.stdout.splitlines() if line.startswith('FUNC_MAP_TARGET ')]
        row = json.loads(targets[-1]) if targets else {'target_executed': False, 'pass': False}
        row.update(arm=arm, mode=name, link_rc=rc, check_rc=check_run.returncode,
                   sha256=hashlib.sha256(dylib.read_bytes()).hexdigest())
        results.append(row)
    return results


with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    results = sum(pool.map(run, ['baseline', 'candidate', 'cut-producer', 'cut-consumer', 'restored']), [])
subprocess.run(['uptime'], stdout=(OUT / 'uptime-after.log').open('w'), check=True)
(OUT / 'results.json').write_text(json.dumps(results, indent=2))
passed = all(r['target_executed'] and r['pass'] == (r['arm'] in ('candidate', 'restored')) and r['check_rc'] == (0 if r['arm'] in ('candidate', 'restored') else 1) for r in results)
for mode in ('all', 'strip'):
    green = next(r for r in results if r['arm'] == 'candidate' and r['mode'] == mode)
    restored = next(r for r in results if r['arm'] == 'restored' and r['mode'] == mode)
    passed = passed and green.get('sha256') == restored.get('sha256')
print('NATIVE_FUNC_MAP_ARMS ' + json.dumps({'cpu': CPU, 'checks': len(results), 'pass': passed}))
raise SystemExit(0 if passed else 1)
