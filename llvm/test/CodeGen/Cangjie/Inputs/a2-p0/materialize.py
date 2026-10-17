#!/usr/bin/env python3
"""Materialize source-based witnesses. Does not invoke any LLVM tool.

Syntax acceptance does not prove a backend route, layout, or managed eligibility.
The inherited edge/platform inventory remains present even for unresolved cases.
"""
import argparse
import hashlib
import json
import datetime
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
    p.add_argument('--execution-identity', required=True)
    a = p.parse_args()
    source_manifest = json.loads(Path(a.inherited).read_text())
    # The inherited namespace is a plan, never the current executor identity.
    inherited = json.loads(json.dumps(source_manifest))
    execution = json.loads(Path(a.execution_identity).read_text())
    for key in ('lane', 'role', 'run', 'session', 'candidate', 'started_utc', 'deadline_utc'):
        if key not in execution:
            raise ValueError('execution identity missing: ' + key)
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
    for arch,clobber in [('x86_64','~{rbp},~{rsp}'),('aarch64','~{x29},~{sp}')]:
        add('asm-layout-clobber-'+arch,['asm-boundary'],fn('call void asm sideeffect "nop", "'+clobber+'"() #0\nret void')+'attributes #0 = { "gc-leaf-function" }\n',
            [anchor('llvm/lib/CodeGen/AsmPrinter/AsmPrinterInlineAsm.cpp',101)],target=[arch],
            limits='IR syntax acceptance only; target constraints and FP/SP layout invalidation require real parser/consumer evidence.')
    add('module-asm-native',['asm-boundary'],'module asm "nop"\n'+fn('ret void',False),
        [anchor(AP,534)],predicates=['No current managed owner for module asm'])
    for arch, text in [('x86_64','.byte 0x90'),('aarch64','.inst 0xd503201f')]:
        add('raw-native-'+arch,['asm-boundary'],'module asm "'+text+'"\n'+fn('ret void',False),
            [anchor('llvm/lib/MC/MCParser/AsmParser.cpp',3196)],target=[arch],
            limits='Raw parser acceptance only; raw managed responsibility remains UNRESOLVED.')
    # CJ intrinsic witnesses follow Statepoint.h IDs and actual target routing.
    # They are not declarations that a metadata-only event has happened.
    cjdecl = 'declare token @llvm.cj.gc.statepoint(...)\n'
    def cjcall(callee,signature='void ()',id_=0,params='',num=0):
        return '%s = call token (...) @llvm.cj.gc.statepoint(i64 '+str(id_)+', i32 0, '+signature+'* @'+callee+', i32 '+str(num)+', i32 0'+(', '+params if params else '')+')'
    for callee,families in [('CJ_MCC_NewObject',['new-object-fast','new-object-normal']),
                             ('CJ_MCC_NewFinalizer',['new-finalizer-fast','new-finalizer-normal'])]:
        declarations = 'declare i8 addrspace(1)* @'+callee+'(i8*, i32)\ndeclare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)\n'
        add('allocate-'+callee, families,cjdecl+declarations+fn(cjcall(callee,'i8 addrspace(1)* (i8*, i32)',params='i8* %ti, i32 32',num=2)+'\nret void',args='i8* %ti'),
            [anchor(AP,4263),anchor(AA,2054),anchor('llvm/test/Transforms/CJRewriteStatepoint/cj-blackhole.ll',18)],
            flags=['--cangjie-pipeline'],predicates=['same IR; fast/normal selected by -enable-cangjie-new-obj-fastpath=true/false'],
            limits='Source-route witness; full allocator ABI/type metadata and X86 jump/stub S proof remain unresolved; no R1 codegen.')
    add('throw-cj',['throw'],cjdecl+'declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)\n'+fn(cjcall('CJ_MCC_ThrowException','void (i8 addrspace(1)*)',params='i8 addrspace(1)* %exception',num=1)+'\nunreachable',args='i8 addrspace(1)* %exception'),
        [anchor(AP,4259),anchor(XX,3699),anchor(AA,2137)],flags=['--cangjie-pipeline'])
    add('stackcheck-cj',['grow','sofe'],cjdecl+'declare void @CJ_MCC_StackCheck()\n'+fn(cjcall('CJ_MCC_StackCheck',id_=5)+'\nret void'),
        [anchor('llvm/include/llvm/IR/Statepoint.h',44),anchor(AA,1242)],flags=['--cangjie-pipeline'],
        predicates=['same IR; grow/overflow selected by -cj-stack-grow=true/false'],limits='Post-body SOFE and saved layout/stub semantics unresolved; this is explicit ID5 input only.')
    for id_,callee,family in [(3,'CJ_MCC_HandleSafepoint','safepoint-inline-short'),(4,'CJ_Safepoint_Stub','safepoint-outline')]:
        add('safepoint-id'+str(id_),[family],cjdecl+'declare void @'+callee+'()\n@CJ_MCC_HandleSafepoint.CJStubGV = external global i8*\n'+fn(cjcall(callee,id_=id_)+'\nret void'),
            [anchor('llvm/include/llvm/IR/Statepoint.h',42),anchor(AA,1353),anchor(AA,1409)],
            flags=['--cangjie-pipeline','-cj-safepoint-outline='+('false' if id_ == 3 else 'true')],
            limits='Actual MI layout, roots and inline/post-body branch reach not verified by llvm-as.')
    add('thread-marker',['marker-metadata-threadid'],
        'declare i64 @GetCJThreadIdForMutexOpt()\ndeclare void @SetDebugLocation()\n'+fn('%t = call i64 @GetCJThreadIdForMutexOpt()\ncall void @SetDebugLocation()\nret void'),
        [anchor('llvm/include/llvm/IR/Function.h',909),anchor(AP,4270)],
        limits='Name predicate closed; return type/ABI and preinit metadata route remain unverified.')
    add('return-naked',['return-negative-attributes'],fn('call void asm sideeffect "", ""()\nret void',attr='naked'),
        [anchor(META,34),anchor('llvm/test/CodeGen/Cangjie/return-poll-funcdesc.ll',37)],
        limits='Syntax only; target naked restrictions must be checked before codegen.')
    add('statepoint-live',['statepoint-global'],decl+spdecl+'declare i32 addrspace(1)* @llvm.experimental.gc.relocate.p1i32(token, i32, i32)\n'+fn('%s = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 0, void ()* elementtype(void ()) @callee, i32 0, i32 0, i32 0, i32 0) ["gc-live"(i32 addrspace(1)* %root)]\n%r = call i32 addrspace(1)* @llvm.experimental.gc.relocate.p1i32(token %s, i32 0, i32 0)\nret i32 addrspace(1)* %r',result='i32 addrspace(1)*',args='i32 addrspace(1)* %root'),
        [anchor(V,2248),anchor('llvm/test/CodeGen/AArch64/statepoint-call-lowering.ll',114)],
        flags=['--cangjie-pipeline'],limits='Live root syntax/relocate indices admitted separately; register allocation and G not executed.')
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
    envelope = {'schema': 'a2-p0-execution-v2', 'execution': execution,
                'scripts': {'materialize_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
                'source_manifest': {'path': str(Path(a.inherited).resolve()),
                                    'sha256': hashlib.sha256(Path(a.inherited).read_bytes()).hexdigest(),
                                    'identity': {k: source_manifest.get(k, 'UNKNOWN') for k in ('lane', 'role', 'created_at')},
                                    'content': source_manifest},
                'prepared_plan': inherited, 'status': 'PREPARED_NOT_EXECUTED'}
    with (out/'execution.json').open('x') as f:
        f.write(json.dumps(envelope, indent=2) + '\n')

if __name__ == '__main__':
    main()
