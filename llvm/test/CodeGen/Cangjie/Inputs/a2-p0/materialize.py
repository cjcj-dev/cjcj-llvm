#!/usr/bin/env python3
"""Materialize source-based witnesses. Does not invoke any LLVM tool.

Syntax acceptance does not prove a backend route, layout, or managed eligibility.
The inherited edge/platform inventory remains present even for unresolved cases.
"""
import argparse
import hashlib
import json
from pathlib import Path

REF = '466752f2b0a17156dadcb48ce1f6fde9c623f352'
AP = 'llvm/lib/CodeGen/AsmPrinter/AsmPrinter.cpp'
AA = 'llvm/lib/Target/AArch64/AArch64AsmPrinter.cpp'
XX = 'llvm/lib/Target/X86/X86MCInstLower.cpp'
META = 'llvm/lib/CodeGen/CJMetadata.cpp'
V = 'llvm/lib/IR/Verifier.cpp'

def anchor(file, line):
    return {'ref': REF, 'file': file, 'line': line}

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--inherited', required=True)
    p.add_argument('--out', required=True)
    a = p.parse_args()
    inherited = json.loads(Path(a.inherited).read_text())
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    package = '\n!llvm.module.flags = !{!0}\n!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}\n'
    decl = 'declare void @callee()\ndeclare void @other()\n'
    spdecl = 'declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64, i32, void ()*, i32, i32, ...)\n'
    def fn(body, gc=True, attr='', result='void', args='void ()* %fp'):
        return f'define {result} @test({args}) {attr} ' + ('gc "cangjie" ' if gc else '') + '{\n' + body + '\n}\n'
    fixtures = []
    def add(name, families, text, anchors, target=None, flags=None, predicates=None, limits=None):
        data = (text + package).encode()
        path = out / (name + '.ll')
        path.write_bytes(data)
        fixtures.append({'id': name, 'path': str(path), 'sha256': hashlib.sha256(data).hexdigest(),
                         'families': families, 'anchors': anchors,
                         'targets': target or ['x86_64', 'aarch64'], 'flags': flags or [],
                         'predicates': predicates or [], 'status': 'MATERIALIZED_NOT_RUN',
                         'reach_status': 'UNVERIFIED_NO_CODEGEN_AUTHORIZED',
                         'limits': limits or 'Syntax only; no managed-run qualification inferred.'})
    body = 'call void @callee()\ncall void %fp()\ncall void @other()\ncall void @callee()\nret void'
    add('ordinary', ['ordinary-multicall'], decl + fn(body), [anchor(AP,429),anchor(AP,1710)],
        predicates=['CJ GC; direct/argument-function-pointer calls; no statepoint'])
    add('native-control', ['noncj-control'], decl + fn(body,False), [anchor(AP,433),anchor(META,34)])
    for name, target in [('statepoint-global','@callee'),('statepoint-register','%fp')]:
        body = '%s = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 0, void ()* elementtype(void ()) ' + target + ', i32 0, i32 0, i32 0, i32 0)\nret void'
        add(name,[name],decl+spdecl+fn(body),[anchor(V,2248),anchor(AA,1378),anchor(XX,1644)],
            flags=['--cangjie-pipeline'], predicates=['ID=0; PatchBytes=0; empty gc-live; global or SSA callee'],
            limits='Empty-root witness only; live-root/relocate witness remains unresolved.')
    for arch, count in [('x86_64',3),('aarch64',4)]:
        body = '%s = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 '+str(count)+', void ()* elementtype(void ()) @callee, i32 0, i32 0, i32 0, i32 0)\nret void'
        add('patch-'+arch,['patch-boundary'],decl+spdecl+fn(body),[anchor(V,2264),anchor(AA,1368),anchor(XX,1671)],
            target=[arch],flags=['--cangjie-pipeline'],predicates=['non-tail; target-aligned nonzero PatchBytes'],
            limits='Encoding reservation P only; hardware H absent before patch; no patcher or managed-run evidence.')
    # Return eligibility is independent of the qualification word.
    add('return-empty-multiexit',['return-roots-empty-multiexit-selectiondag'],
        fn('br i1 %b, label %a, label %z\na:\nret void\nz:\ncall void @callee()\nret void',args='i1 %b')+decl,
        [anchor(META,34),anchor(XX,1499),anchor(AA,2362)],flags=['--cangjie-pipeline','-fast-isel=false'])
    add('return-reference',['return-roots-empty-multiexit-selectiondag'],
        fn('ret i8 addrspace(1)* %root',result='i8 addrspace(1)*',args='i8 addrspace(1)* %root'),
        [anchor(META,34),anchor(XX,1499),anchor(AA,2362)],flags=['--cangjie-pipeline','-fast-isel=false'],
        limits='Return register expectation needs target ABI lowering witness; not inferred from Q or map.')
    for name, gc, attr in [('leaf',True,'"gc-leaf-function"'),('fast',True,'"cj_fast_call"'),('native',False,'')]:
        add('return-negative-'+name,['return-negative-attributes'],fn('ret void',gc,attr),[anchor(META,34)],
            predicates=['Eligibility false by actual GC/attribute predicate; naked witness remains unresolved'])
    # Typed asm is a real parser route, not a statepoint or raw-byte contract.
    for arch, instruction, constraint in [('x86_64','callq callee','~{dirflag},~{fpsr},~{flags}'),
                                          ('aarch64','bl callee','~{x30}')]:
        add('asm-direct-'+arch,['asm-boundary'],decl+fn('call void asm sideeffect "'+instruction+'", "'+constraint+'"() #0\nret void')+'attributes #0 = { "gc-leaf-function" }\n',
            [anchor('llvm/lib/CodeGen/AsmPrinter/AsmPrinterInlineAsm.cpp',101),anchor('llvm/lib/Transforms/Scalar/CJRewriteStatepoint.cpp',3128)],
            target=[arch],predicates=['Typed inline asm direct call; leaf call attribute avoids automatic rewrite'],
            limits='Leaf attribute is not authorization to hide GC; suspended layout and roots not qualified.')
    add('asm-indirect-x86',['asm-boundary'],fn('call void asm sideeffect "callq *$0", "r,~{dirflag},~{fpsr},~{flags}"(void ()* %fp) #0\nret void')+'attributes #0 = { "gc-leaf-function" }\n',
        [anchor('llvm/lib/CodeGen/AsmPrinter/AsmPrinterInlineAsm.cpp',101)],target=['x86_64'])
    add('asm-indirect-aarch64',['asm-boundary'],fn('call void asm sideeffect "blr $0", "r,~{x30}"(void ()* %fp) #0\nret void')+'attributes #0 = { "gc-leaf-function" }\n',
        [anchor('llvm/lib/CodeGen/AsmPrinter/AsmPrinterInlineAsm.cpp',101)],target=['aarch64'])
    add('module-asm-native',['asm-boundary'],'module asm "nop"\n'+fn('ret void',False),
        [anchor(AP,534)],predicates=['No current managed owner for module asm'])
    for arch, text in [('x86_64','.byte 0x90'),('aarch64','.inst 0xd503201f')]:
        add('raw-native-'+arch,['asm-boundary'],'module asm "'+text+'"\n'+fn('ret void',False),
            [anchor('llvm/lib/MC/MCParser/AsmParser.cpp',3196)],target=[arch],
            limits='Raw parser acceptance only; raw managed responsibility remains UNRESOLVED.')
    inherited['materialized_inputs'] = fixtures
    for case in inherited['event_cases']:
        matches = [f['id'] for f in fixtures if case['id'] in f['families']]
        case['p0_inputs'] = matches
        case['p0_status'] = 'PARTIAL_MATERIALIZED' if matches else 'UNRESOLVED'
        if not matches:
            case['p0_missing_contract'] = case.get('unresolved') or ('Exact source-based IR witness and lowering/stub layout proof missing; no guessed generator or codegen.')
        case['validated_fixture'] = False
    inherited['object_formats'] = {'ELF': 'implemented bounded little-endian ELF64 ET_REL',
                                    'COFF': 'UNVERIFIED; relocation/descriptor decoder missing',
                                    'MachO': 'UNVERIFIED; paired/subtractor relocation decoder missing'}
    inherited['Q62_configuration_gate_satisfied'] = False
    inherited['p0_counts'] = {'unique_new_ir': len(fixtures), 'syntax_executed':0,'object_checks_executed':0}
    (out/'execution.json').write_text(json.dumps(inherited,indent=2)+'\n')

if __name__ == '__main__':
    main()
