#!/usr/bin/env python3
"""Emit native inputs on the LLVM build host; retain producer identity with bytes."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--tools', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
p.add_argument('--source-root', type=Path)
a = p.parse_args()
if a.source_root is None:
    a.source_root = Path(__file__).resolve().parents[3]
source = Path(__file__).with_name('pair.ll')
a.out.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
head = subprocess.run(['git', '-C', a.source_root, 'rev-parse', 'HEAD'],
                      capture_output=True, text=True, check=True).stdout.strip()
manifest = {'llvm_head': head,
            'ir_sha256': sha(source), 'objects': [],
            'product_sources': {name: sha(a.source_root/name) for name in [
                'llvm/lib/CodeGen/AsmPrinter/AsmPrinter.cpp',
                'llvm/lib/Target/X86/X86MCInstLower.cpp',
                'llvm/lib/Target/AArch64/AArch64AsmPrinter.cpp']}}
for target, triple in [('x86_64-macos', 'x86_64-apple-macosx11.0'),
                       ('aarch64-macos', 'aarch64-apple-macosx11.0'),
                       ('x86_64-windows', 'x86_64-pc-windows-msvc')]:
    for arm, toolarm in [('candidate', 'release'), ('cut-producer', 'cut-producer')]:
        llc = a.tools/toolarm/'llc'
        obj = a.out/(target+'-'+arm+'.o')
        cmd = [str(llc), '--cangjie-pipeline', '-mtriple='+triple,
               '-filetype=obj', str(source), '-o', str(obj)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        (a.out/(target+'-'+arm+'.log')).write_text(result.stdout+result.stderr)
        result.check_returncode()
        manifest['objects'].append({'target': target, 'triple': triple, 'arm': arm,
            'llc_sha256': sha(llc), 'command': cmd, 'rc': result.returncode,
            'sha256': sha(obj), 'base64': base64.b64encode(obj.read_bytes()).decode()})
(a.out/'objects.json').write_text(json.dumps(manifest, indent=2)+'\n')
