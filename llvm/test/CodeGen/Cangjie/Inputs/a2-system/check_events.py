#!/usr/bin/env python3
"""Unexecuted finite ELF encoding checker; not a managed-runtime clearance.

Reuse only the independent ELF, instruction and compressed-G readers from P0.
H/S/R come from instructions/relocations/saved arguments, never Q. The source
predicate and ABI return root are separate from descriptor qualification.
This file is not installed in lit/CI or the rejected generic runner.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'a2-p0'))
import object_check as reader


def identity(path, expected):
    value = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    reader.require(value == expected, 'identity mismatch: ' + str(path))
    return value


def source_contract(text, name, machine):
    m = re.search(r'define\s+(.+?)@' + re.escape(name) + r'\b(.*?)\{', text, re.S)
    reader.require(m is not None, 'source function absent')
    signature, attrs = m.groups()
    for group in re.findall(r'#(\d+)\b', attrs):
        a = re.search(r'attributes\s+#' + group + r'\s*=\s*\{([^}]*)\}', text)
        reader.require(a is not None, 'source attribute group absent')
        attrs += a.group(1)
    managed = 'gc "cangjie"' in attrs
    eligible = managed and not any(x in attrs for x in ('gc-leaf-function', 'cj_fast_call', 'naked'))
    reader.require(not re.search(r'\b(?:fastcc|coldcc|cc\s+\d+)\b', signature), 'UNRESOLVED_RETURN_CALLING_CONVENTION')
    if re.search(r'\bi\d+\s+addrspace\(1\)\s*\*\s*$', signature):
        # Default scalar pointer C ABI: DWARF rax/x0 = 0. This is source/ISA
        # expected state, not a mask copied from a graph or Q row.
        root = 1
    else:
        reader.require(re.search(r'\b(?:void|i\d+|float|double)\s*$', signature) is not None,
                       'UNRESOLVED_RETURN_ABI: aggregate/other type')
        root = 0
    fp = ('~{rbp}' in text) if machine == 62 else ('~{x29}' in text or '~{fp}' in text)
    sp = ('~{rsp}' in text or 'pushq %' in text) if machine == 62 else ('~{sp}' in text or 'sub sp, sp,' in text)
    clear = 3 if fp else (2 if sp else 0)
    ids = {int(x) for x in re.findall(r'@llvm\.(?:cj\.gc|experimental\.gc)\.statepoint[^\s(]*\(i64\s+(\d+)', text)}
    patches = [(int(i), int(n)) for i, n in re.findall(
        r'@llvm\.(?:cj\.gc|experimental\.gc)\.statepoint[^\s(]*\(i64\s+(\d+),\s*i32\s+(\d+)', text) if int(n)]
    return managed, eligible, root, clear, ids, patches


def observations(elf, fn, ins):
    """Decode both independent sides of return saved-site correspondence."""
    entry = fn['value']
    calls, polls, branches, saved = {}, set(), set(), []
    for i, (at, raw, asm) in enumerate(ins):
        word = int.from_bytes(raw, 'little')
        call = bool(re.match(r'callq?\s', asm)) if elf.machine == 62 else (
            word & 0xfc000000 == 0x94000000 or word & 0xfffffc1f == 0xd63f0000)
        if call:
            # Direct relocation or the short target materialization immediately
            # before an indirect call. Never use Q to classify an event.
            refs = [r['symbol']['name'] for (sec, pos), r in elf.relocs.items()
                    if sec == fn['section'] and at <= pos < at+len(raw)]
            if not refs:
                reg = re.search(r'callq?\s+\*%([a-z0-9]+)', asm) if elf.machine == 62 else re.search(r'blr\s+(x\d+)', asm)
                if reg:
                    for start, code, prior in ins[max(0, i-3):i]:
                        prior = prior.split('#', 1)[0].strip()
                        load = (prior.startswith('mov') and prior.endswith('%'+reg.group(1))) if elf.machine == 62 else bool(re.match(r'(?:adrp|ldr|add|mov)\s+'+reg.group(1)+r',', prior))
                        if load:
                            refs.extend(r['symbol']['name'] for (sec,pos),r in elf.relocs.items()
                                        if sec == fn['section'] and start <= pos < start+len(code))
            calls[at+len(raw)-entry] = refs
        if elf.machine == 62:
            if raw == bytes.fromhex('493b6730'):
                reader.require(i+1 < len(ins) and ins[i+1][1][:2] == b'\x0f\x87', 'unsupported return branch')
                polls.add(at-entry)
                b, code, _ = ins[i+1]
                reader.require(len(code) == 6, 'unsupported return branch width')
                branches.add(b+6+struct.unpack_from('<i', code, 2)[0])
            if raw[:2] == b'\xff\x25':
                r = elf.relocs.get((fn['section'], at+2))
                if r and r['symbol']['name'] == 'CJ_MCC_HandleReturnSafepoint':
                    reader.require(i >= 2, 'return arguments absent')
                    seq = ins[i-2:i]
                    reader.require(seq[0][1][:3] == b'\x4c\x8d\x15' and seq[1][1][:3] == b'\x4c\x8d\x1d', 'UNRESOLVED_RETURN_ARGUMENT_ENCODING')
                    vals = [a+7+struct.unpack_from('<i', b, 3)[0] for a, b, _ in seq]
                    saved.append((seq[0][0], vals[0], vals[1]-entry))
        else:
            if word == 0xf9401b90:
                reader.require(i+2 < len(ins) and int.from_bytes(ins[i+1][1], 'little') == 0xeb3063ff and int.from_bytes(ins[i+2][1], 'little') & 0xff00001f == 0x54000008, 'unsupported return poll')
                polls.add(at-entry)
                b, code, _ = ins[i+2]
                disp = (int.from_bytes(code, 'little') >> 5) & 0x7ffff
                if disp & (1 << 18):
                    disp -= 1 << 19
                branches.add(b+4*disp)
            if word == 0xd61f0120 and i >= 4:
                seq = ins[i-4:i]
                r = elf.relocs.get((fn['section'], seq[0][0]))
                if r and r['symbol']['name'] == 'CJ_MCC_HandleReturnSafepoint':
                    lo = elf.relocs.get((fn['section'], seq[1][0]))
                    reader.require(lo and lo['symbol']['name'] == r['symbol']['name'], 'unsupported handler address')
                    vals = []
                    for (addr, data, _), reg in zip(seq[2:], (17, 16)):
                        w = int.from_bytes(data, 'little')
                        reader.require(w & 0x9f00001f == 0x10000000+reg, 'UNRESOLVED_RETURN_ARGUMENT_ENCODING')
                        disp = ((w >> 5) & 0x7ffff) << 2 | ((w >> 29) & 3)
                        if disp & (1 << 20):
                            disp -= 1 << 21
                        vals.append(addr+disp)
                    saved.append((seq[0][0], vals[0], vals[1]-entry))
    rets = sum(bool(re.match(r'ret(?:q|aa|ab)?(?:\s|$)', asm)) for _, _, asm in ins)
    return calls, polls, branches, saved, rets



def helper_coverage(elf, fn, ins, disassembly, witness, report, assertion):
    """One AArch64 local BL edge; never merge helper PCs into managed Q/G."""
    binding = witness['call_owner']
    reader.require(elf.machine == 183, 'UNRESOLVED_HELPER_ISA')
    edges = []
    for at, raw, _ in ins:
        word = int.from_bytes(raw, 'little')
        if word & 0xfc000000 != 0x94000000:
            continue
        if (fn['section'], at) in elf.relocs:
            continue
        disp = word & 0x03ffffff
        if disp & (1 << 25):
            disp -= 1 << 26
        target = at + 4 * disp
        owners = [f for f in elf.functions if f['section'] == fn['section']
                  and f['value'] <= target < f['value'] + f['size']]
        reader.require(len(owners) == 1, 'PRECONDITION_LOCAL_BL_OWNER')
        edges.append((at, target, owners[0]))
    reader.require(len(edges) == 1, 'PRECONDITION_SINGLE_LOCAL_BL')
    at, target, owner = edges[0]
    owner_ins = reader.instructions(elf, disassembly, owner)
    helper_calls, _, _, _, _ = observations(elf, owner, owner_ins)
    matches = {}
    relocation_calls = {}
    for pc in helper_calls:
        call_at = owner['value'] + pc - 4
        relocation = elf.relocs.get((owner['section'], call_at))
        if relocation and relocation['type'] == 283 and relocation['addend'] == 0:
            relocation_calls[pc] = relocation['symbol']['name']
    for required in witness['required_calls']:
        matches[required['name']] = sorted(pc for pc, symbol in relocation_calls.items()
            if re.fullmatch(required['symbol_regex'], symbol))
    report['helper_coverage'] = dict(owner=owner, local_bl=at, target=target,
        calls=sorted(helper_calls), call26=relocation_calls, branches=matches,
        attribute_source='CJBarrierLowering.cpp:1272 replaceFastFunc; no original IR definition; no managed qualification claim')
    assertion('helper_owner_binding', target == owner['value'] and
        at - fn['value'] == binding['local_bl_offset'] and
        owner['name'] == binding['name'] and owner['value'] == binding['entry'] and
        owner['size'] == binding['size'] and
        elf.names[binding['section']] == owner['section'] and owner != fn,
        dict(decoded_target=target, actual_owner=owner, expected=binding))
    assertion('helper_call_coverage', len(helper_calls) >= witness['min_calls'] and
        all(len(matches[r['name']]) >= r['min_count'] for r in witness['required_calls']),
        dict(calls=sorted(helper_calls), call26=relocation_calls, branches=matches,
             min_calls=witness['min_calls']))


def check(a, report):
    identity(a.source, a.source_sha256)
    identity(a.object, a.object_sha256)
    identity(a.objdump, a.objdump_sha256)
    identity(a.witness, a.witness_sha256)
    witness = json.loads(Path(a.witness).read_text())
    elf = reader.ELF(Path(a.object).read_bytes())
    fns = [f for f in elf.functions if f['name'] == a.function]
    reader.require(len(fns) == 1, 'ambiguous function identity')
    fn = fns[0]
    text = Path(a.source).read_text()
    managed, eligible, root, clear, ids, patches = source_contract(text, a.function, elf.machine)
    d = subprocess.run([a.objdump, '-d', a.object], capture_output=True, text=True)
    report.update(objdump_argv=d.args, objdump_rc=d.returncode, disassembly=d.stdout)
    reader.require(d.returncode == 0, 'objdump did not complete')
    mi = elf.names.get('.cjmetadata.methodinfo')
    associated = [] if mi is None else [at for at in range(0, len(elf.bytes(mi)), 48)
                 if elf.relative(mi, at+32) == (fn['section'], fn['value'])]
    def assertion(axis, ok, detail):
        report.setdefault('assertions', []).append(dict(axis=axis, reached=True, passed=bool(ok), detail=detail))
    if not managed:
        qualified = [at for at in associated if struct.unpack_from('<I', elf.bytes(mi), at+40)[0] == 0x31514a43]
        assertion('native_owner', not qualified, qualified)
        return
    reader.require(len(associated) == 1, 'managed descriptor association absent/ambiguous')
    at = associated[0]
    desc = elf.bytes(mi)
    reader.require(struct.unpack_from('<I', desc, at+40)[0] == 0x31514a43, 'qualification tag absent')
    q = elf.relative(mi, at+36)
    reader.require(q and q[0] == elf.names.get('.cjmetadata.stackmap'), 'qualification range absent')
    maps = elf.bytes(q[0])
    magic, size, nt, nq = struct.unpack_from('<IIII', maps, q[1])
    reader.require(magic == 0x31514a43 and size == 16+8*(nt+nq) and q[1]+size <= len(maps), 'qualification structural bounds')
    rows = [struct.unpack_from('<IHH', maps, q[1]+16+8*nt+8*i) for i in range(nq)]
    ins = reader.instructions(elf, d.stdout, fn)
    calls, polls, branches, saved, rets = observations(elf, fn, ins)
    # Coverage is a prerequisite, separate from the relation assertions below.
    # A missing branch is UNRESOLVED, never an accepted narrow-cut failure.
    if 'call_owner' in witness:
        helper_coverage(elf, fn, ins, d.stdout, witness, report, assertion)
    else:
        reader.require(len(calls) >= witness['min_calls'], 'PRECONDITION_CALL_COUNT')
    reader.require(len(polls) >= witness['min_polls'], 'PRECONDITION_POLL_COUNT')
    def matching_calls(pattern):
        return {pc for pc, refs in calls.items()
                if any(re.fullmatch(pattern, ref) for ref in refs)}
    branch_calls = {}
    for required in ([] if 'call_owner' in witness else witness['required_calls']):
        pcs = matching_calls(required['symbol_regex'])
        reader.require(len(pcs) >= required['min_count'],
                       'PRECONDITION_BRANCH: ' + required['name'])
        branch_calls[required['name']] = sorted(pcs)
    reader.require(not witness['require_nonempty_return'] or (root != 0 and polls),
                   'PRECONDITION_NONEMPTY_RETURN_ABI')
    report.update(coverage=dict(calls=sorted(calls), polls=sorted(polls),
                                branches=branch_calls, witness=witness))
    kinds = {}
    for pc, refs in calls.items():
        is_stub = ((3 in ids or 4 in ids) and any('Safepoint' in x for x in refs)) or (
                   5 in ids and a.grow and any('CJ_MCC_StackGrowStub' in x for x in refs))
        kinds[pc] = 2 if is_stub else 1
    reserved = set()
    # LowerSTATEPOINT routes these IDs before it examines PatchBytes. Preserve
    # those legal inputs; only the actual reserved route has a NOP completion PC.
    reserved_patches = [(i, n) for i, n in patches if not (
        a.pipeline and ((i == 3 and not a.outline) or i in (5, 6)))]
    if reserved_patches:
        reader.require(len(reserved_patches) == 1, 'UNRESOLVED_MULTIPLE_PATCH_REGIONS')
        patch_id, patch_bytes = reserved_patches[0]
        nops, run = [], []
        for inst in ins + [(0, b'', '')]:
            if re.match(r'nop\w*\b', inst[2]):
                run.append(inst)
            else:
                if run and sum(len(x[1]) for x in run) == patch_bytes:
                    nops.append(run[-1][0]+len(run[-1][1])-fn['value'])
                run = []
        reader.require(len(nops) == 1, 'UNRESOLVED_PATCH_REGION_IDENTITY')
        reserved.update(nops)
        kinds[nops[0]] = 2 if patch_id in (3, 4) else 1
    expected = {(pc, kind) for pc, kind in kinds.items()} | {(pc, 3) for pc in polls}
    actual = {(pc, kind) for pc, kind, bits in rows}
    graph_ref = elf.relative(mi, at)
    graph = dict(state='absent', rows={})
    if graph_ref:
        reader.require(graph_ref[0] == q[0] and graph_ref[1] < q[1], 'graph range association')
        graph = reader.decode_graph(maps[graph_ref[1]:q[1]])
    report.update(H=sorted(calls), S_kind2=sorted(pc for pc,k in kinds.items() if k == 2 and pc not in reserved),
                  reserved_patch=sorted(reserved), R=sorted(polls), saved=saved, Q=rows, G=graph,
                  layout_scope='cleared bits only; independent positive FULL/slot proof still required')
    assertion('unique_event', len(actual) == len(rows), 'same PC/kind must not be deduplicated')
    assertion('saved_pc_kind', actual == expected, dict(extra=sorted(actual-expected), missing=sorted(expected-actual)))
    assertion('return_bits', all(bits == 0 for pc,kind,bits in rows if kind == 3), 'poll bits0')
    assertion('return_flag', struct.unpack_from('<I', desc, at+28)[0] == int(eligible), 'original source/OS eligibility; tail-only functions need not emit a RET')
    assertion('return_count', len(polls) == (rets if eligible else 0), dict(polls=len(polls), machine_returns=rets))
    assertion('stub_owner', all(entry == fn['value'] for _,entry,_ in saved), 'actual stub entry arguments')
    assertion('stub_site', len(saved) == len(polls) and {pc for _,_,pc in saved} == polls, 'actual saved site vs poll starts')
    assertion('stub_branch', branches == {at for at,_,_ in saved}, 'real slow-branch targets')
    assertion('return_roots', all(pc in graph['rows'] and graph['rows'][pc]['register_mask'] == root and
              all(graph['rows'][pc]['indices'][i] == 0 for i in (1,3,4,5)) for pc in polls), dict(expected_mask=root, poll_pcs=sorted(polls)))
    if clear:
        reader.require('call void asm' in text and not re.search(r'call void @', text), 'UNRESOLVED_MIXED_ASM_LAYOUT_WITNESS')
        assertion('asm_layout_clear', all(not (bits & clear) for pc,kind,bits in rows if kind in (1,2)), dict(clear=clear, calls=len(calls)))
    graph_pcs = set()
    for required in witness['graph_calls']:
        pcs = matching_calls(required['symbol_regex'])
        reader.require(len(pcs) >= required['min_count'], 'PRECONDITION_GRAPH_SAVE_POINT')
        graph_pcs.update(pcs)
    if '"gc-live"' in text:
        reader.require(graph_pcs, 'UNRESOLVED_GRAPH_SAVE_POINT_SPECIFICATION')
    if graph_pcs:
        assertion('live_call_graph', all(pc in graph['rows'] and graph['rows'][pc]['state'] == 'nonempty' for pc in graph_pcs),
                  dict(independent_machine_saved_pcs=sorted(graph_pcs)))


def main():
    p = argparse.ArgumentParser()
    for name in ('source', 'source-sha256', 'object', 'object-sha256', 'objdump', 'objdump-sha256', 'witness', 'witness-sha256', 'out'):
        p.add_argument('--' + name, required=True)
    p.add_argument('--function', default='test')
    p.add_argument('--grow', action='store_true')
    p.add_argument('--pipeline', action='store_true')
    p.add_argument('--outline', action='store_true')
    a = p.parse_args()
    report = dict(status='UNRESOLVED', scope='finite ELF64 ET_REL encoding; not complete saved-layout or runtime acceptance',
                  managed_runtime_qualification=False, checker_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  reader_sha256=hashlib.sha256(Path(reader.__file__).read_bytes()).hexdigest())
    rc = 2
    try:
        check(a, report)
        report['status'] = 'PASS' if all(x['passed'] for x in report['assertions']) else 'FAIL'
        rc = int(report['status'] != 'PASS')
    except (reader.Unresolved, OSError, ValueError, KeyError, struct.error, IndexError) as e:
        report['reason'] = str(e)
    report['rc'] = rc
    Path(a.out).write_text(json.dumps(report, indent=2) + '\n')
    return rc


if __name__ == '__main__':
    raise SystemExit(main())
