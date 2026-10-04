#!/usr/bin/env python3
"""Bounded independent object checker; never executes or generates target code.

H is decoded from instructions within ELF STT_FUNC extents. R comes from the
poll and actual slow-stub entry/site arguments, not qualification rows. G uses
the runtime nibble-varint/bit-table format. Unknown routes/formats are not PASS.
This P0 implementation deliberately does not claim COFF/MachO acceptance.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path

class Unresolved(Exception):
    pass

def require(condition, message):
    if not condition:
        raise Unresolved(message)

class ELF:
    def __init__(self, data):
        self.data = data
        require(data[:6] == b'\x7fELF\x02\x01', 'UNSUPPORTED_FORMAT: ELF64 little endian required; COFF/MachO obligations remain')
        require(self.u('H',16) == 1, 'UNSUPPORTED_FORMAT: linked ELF needs dynamic relocation/address support')
        self.machine = self.u('H',18)
        require(self.machine in (62,183), 'UNSUPPORTED_ARCH')
        off = self.u('Q',40)
        size,count,strings = self.unpack('HHH',58)
        require(size == 64 and 0 < strings < count, 'unsupported extended section table')
        self.headers = [self.unpack('IIQQQQIIQQ',off+i*size) for i in range(count)]
        names = self.bytes(strings)
        self.names = {self.cstr(names,h[0]):i for i,h in enumerate(self.headers)}
        require(len(self.names) == len(self.headers), 'ambiguous section names')
        self.symtabs = {}
        self.functions = []
        self.mappings = []
        for i,h in enumerate(self.headers):
            if h[1] != 2:
                continue
            require(h[9] == 24 and h[5] % 24 == 0, 'invalid symtab')
            strings = self.bytes(h[6])
            symbols = []
            for pos in range(h[4],h[4]+h[5],24):
                name,info,other,sec,value,extent = self.unpack('IBBHQQ',pos)
                name = self.cstr(strings,name)
                sym = {'name':name,'section':sec,'value':value,'size':extent}
                symbols.append(sym)
                if info & 15 == 2 and 0 < sec < len(self.headers) and extent:
                    self.functions.append(sym)
                if name in ('$x','$d') or name.startswith(('$x.','$d.')):
                    self.mappings.append((sec,value,name[:2]))
            self.symtabs[i] = symbols
        self.relocs = {}
        for h in self.headers:
            if h[1] != 4:
                continue
            require(h[9] == 24 and h[5]%24 == 0 and h[6] in self.symtabs, 'invalid RELA')
            for pos in range(h[4],h[4]+h[5],24):
                at,info,addend = self.unpack('QQq',pos)
                syms = self.symtabs[h[6]]
                require(info >> 32 < len(syms), 'relocation symbol out of bounds')
                key = (h[7],at)
                require(key not in self.relocs, 'duplicate relocation')
                self.relocs[key] = {'type':info&0xffffffff,'symbol':syms[info>>32],'addend':addend}

    def unpack(self, fmt, off):
        size = struct.calcsize('<'+fmt)
        require(0 <= off <= len(self.data)-size, 'truncated object field')
        return struct.unpack_from('<'+fmt,self.data,off)

    def u(self,fmt,off):
        return self.unpack(fmt,off)[0]

    @staticmethod
    def cstr(data,off):
        require(0 <= off < len(data), 'invalid string offset')
        end = data.find(b'\0',off)
        require(end >= 0, 'unterminated string')
        return data[off:end].decode('utf-8')

    def bytes(self,sec):
        require(0 <= sec < len(self.headers), 'invalid section index')
        h = self.headers[sec]
        require(h[4]+h[5] <= len(self.data), 'truncated section')
        return self.data[h[4]:h[4]+h[5]]

    def relative(self,sec,at):
        r = self.relocs.get((sec,at))
        if r is None:
            value = struct.unpack_from('<i',self.bytes(sec),at)[0]
            if value == 0:
                return None
            raise Unresolved('relative pointer without supported relocation')
        require(r['type'] == (2 if self.machine == 62 else 261), 'unexpected metadata PC-relative relocation')
        sym = r['symbol']
        require(0 < sym['section'] < len(self.headers), 'metadata reference to undefined symbol')
        return (sym['section'],sym['value']+r['addend'])

class Bits:
    # Consumer anchor: runtime/src/StackMap/StackMapTable.h:23,94-141.
    def __init__(self,data):
        self.data = data
        self.pos = 0

    def take(self,width):
        require(0 <= width <= 64 and self.pos+width <= 8*len(self.data), 'truncated compressed map')
        value = 0
        for i in range(width):
            value |= ((self.data[(self.pos+i)//8] >> ((self.pos+i)%8)) & 1) << i
        self.pos += width
        return value

    def var(self):
        tag = self.take(4)
        return tag if tag < 12 else self.take(8*(tag-11))

    def align(self):
        padding = (-self.pos)%8
        require(self.take(padding) == 0, 'nonzero map alignment padding')

def decode_graph(data):
    """Decode old bitmap map independently using consumer table indices.

    Format 1 compressed slots and alternate non-copy-GC layout remain explicit
    unresolved; no producer-generated expected blob is accepted as an oracle.
    """
    b = Bits(data)
    stack_size,fmt,saved = b.var(),b.var(),b.var()
    require(fmt == 0, 'UNRESOLVED_GRAPH_FORMAT: compressed slot bitmap')
    for _ in range(saved.bit_count()):
        b.var()
    count = b.var()
    require(count <= len(data), 'invalid map row count')
    widths = [b.var() for _ in range(6)] if count else []
    require(all(w <= 32 for w in widths), 'invalid map column width')
    padding = b.var()
    require(padding < 8 and b.take(padding) == 0 and b.pos % 8 == 0, 'invalid map header padding')
    rows = []
    for _ in range(count):
        pc = b.take(32)
        indices = [b.take(w) for w in widths]
        b.align()
        rows.append((pc,indices))
    require(len({pc for pc,_ in rows}) == len(rows), 'duplicate map PC')
    if not count:
        return {'state':'zero_entries','stack_size':stack_size,'rows':{},'consumed':(b.pos+7)//8}
    nr,rw = b.var(),b.var()
    require(nr <= len(data) and rw <= 64, 'invalid register table')
    registers = [0]+[b.take(rw) for _ in range(nr)]
    ns,basewidth,slotwidth = b.var(),b.var(),b.var()
    require(ns <= len(data) and basewidth <= 32 and slotwidth <= 64, 'unsupported slot table width')
    slots = [(b.take(basewidth),b.take(slotwidth)) for _ in range(ns)]
    nl,lw = b.var(),b.var()
    require(nl <= len(data) and lw <= 32, 'invalid line table')
    for _ in range(nl):
        b.take(lw)
    nd = b.var()
    require(nd <= len(data), 'invalid derived table')
    for _ in range(nd):
        b.take(widths[0]); b.take(widths[1])
    maps = {}
    for pc,idx in rows:
        require(idx[0] < len(registers) and idx[4] < len(registers) and idx[1] <= ns and idx[5] <= ns and idx[2] <= nl and idx[3] <= nd, 'map index out of bounds')
        # Return roots must be register-only; slot/derived/SP references are
        # reported rather than silently discarded by the return comparison.
        maps[pc] = {'state':'empty' if not idx[0] and not idx[1] and not idx[3] else 'nonempty',
                    'register_mask':registers[idx[0]],'indices':idx,'slots':slots}
    return {'state':'present','stack_size':stack_size,'rows':maps,'consumed':(b.pos+7)//8}

def instructions(elf,disassembly,fn):
    sec = next(name for name,i in elf.names.items() if i == fn['section'])
    active = None
    result = []
    mappings = sorted((value,kind) for index,value,kind in elf.mappings if index == fn['section'])
    for line in disassembly.splitlines():
        if line.startswith('Disassembly of section '):
            active = line[23:].rstrip(':')
        if active != sec:
            continue
        m = re.match(r'\s*([0-9a-f]+):\s+(.*)',line)
        if not m:
            continue
        at = int(m[1],16)
        if not fn['value'] <= at < fn['value']+fn['size']:
            continue
        prior = [kind for value,kind in mappings if value <= at]
        require(not prior or prior[-1] != '$d', 'UNRESOLVED_INLINE_DATA_IN_FUNCTION')
        pat = r'((?:[0-9a-f]{2}\s+)+)\s*(\S.*)' if elf.machine == 62 else r'([0-9a-f]{8})\s+(\S.*)'
        inst = re.fullmatch(pat,m[2])
        require(inst is not None, 'unparsed instruction: '+line)
        raw = bytes.fromhex(inst[1]) if elf.machine == 62 else bytes.fromhex(inst[1])[::-1]
        require(0 < len(raw) <= (15 if elf.machine == 62 else 4), 'invalid instruction width')
        require(elf.bytes(fn['section'])[at:at+len(raw)] == raw, 'disassembly/object bytes differ')
        require('<unknown>' not in inst[2], 'unknown instruction')
        result.append((at,raw,inst[2]))
    require(result and result[0][0] == fn['value'], 'function start not decoded')
    require(all(result[i][0]+len(result[i][1]) == result[i+1][0] for i in range(len(result)-1)), 'function instruction gap')
    require(result[-1][0]+len(result[-1][1]) == fn['value']+fn['size'], 'function extent not fully decoded')
    return result

def hardware_and_return(elf,fn,ins):
    h = set()
    polls = set()
    stub_sites = []
    slow_targets = set()
    stubs = set()
    entry = fn['value']
    for i,(at,raw,asm) in enumerate(ins):
        if elf.machine == 62:
            if re.match(r'callq?\s',asm):
                require(raw[0] == 0xe8 or raw[0] == 0xff or (0x40 <= raw[0] <= 0x4f and raw[1] == 0xff), 'unsupported x86 call encoding')
                h.add(at+len(raw)-entry)
            if raw == bytes.fromhex('493b6730'):
                require(i+1 < len(ins) and ins[i+1][1][:2] == b'\x0f\x87', 'return cmp lacks ja')
                polls.add(at-entry)
                branch,code,_ = ins[i+1]
                require(len(code) == 6, 'unsupported return branch width')
                slow_targets.add(branch+6+struct.unpack_from('<i',code,2)[0])
            if raw[:2] == b'\xff\x25':
                r = elf.relocs.get((fn['section'],at+2))
                if r and r['symbol']['name'] == 'CJ_MCC_HandleReturnSafepoint':
                    require(r['type'] in (9,41,42), 'return handler GOT relocation type')
                    require(i >= 2, 'return stub arguments absent')
                    args = ins[i-2:i]
                    require(args[0][1][:3] == b'\x4c\x8d\x15' and args[1][1][:3] == b'\x4c\x8d\x1d', 'return entry/site register mismatch')
                    values = [a+7+struct.unpack_from('<i',v,3)[0] for a,v,_ in args]
                    require(values[0] == entry, 'return stub entry does not match owner')
                    stub_sites.append(values[1]-entry)
                    stubs.add(args[0][0])
        else:
            word = int.from_bytes(raw,'little')
            if word & 0xfc000000 == 0x94000000 or word & 0xfffffc1f == 0xd63f0000:
                h.add(at+4-entry)
            if word == 0xf9401b90:
                require(i+2 < len(ins) and int.from_bytes(ins[i+1][1],'little') == 0xeb3063ff and int.from_bytes(ins[i+2][1],'little') & 0xff00001f == 0x54000008, 'return load lacks compare/HI branch')
                polls.add(at-entry)
                branch,code,_ = ins[i+2]
                disp = (int.from_bytes(code,'little')>>5)&0x7ffff
                if disp & (1<<18):
                    disp -= 1<<19
                slow_targets.add(branch+4*disp)
            if word == 0xd61f0120 and i >= 4:
                seq = ins[i-4:i]
                r = elf.relocs.get((fn['section'],seq[0][0]))
                if r and r['symbol']['name'] == 'CJ_MCC_HandleReturnSafepoint':
                    require(r['type'] == 311, 'return handler GOT page relocation')
                    lo = elf.relocs.get((fn['section'],seq[1][0]))
                    require(lo and lo['type'] == 312 and lo['symbol']['name'] == r['symbol']['name'], 'return handler GOT low relocation')
                    require(int.from_bytes(seq[0][1],'little') & 0x9f00001f == 0x90000009 and int.from_bytes(seq[1][1],'little') & 0xffc003ff == 0xf9400129, 'handler must load into x9')
                    values = []
                    for (addr,bytes_,_),reg in zip(seq[2:],(17,16)):
                        w = int.from_bytes(bytes_,'little')
                        require(w & 0x9f00001f == 0x10000000+reg, 'return entry/site ADR register mismatch')
                        disp = ((w>>5)&0x7ffff)<<2 | ((w>>29)&3)
                        if disp & (1<<20):
                            disp -= 1<<21
                        values.append(addr+disp)
                    require(values[0] == entry, 'return stub entry does not match owner')
                    stub_sites.append(values[1]-entry)
                    stubs.add(seq[0][0])
    require(len(stub_sites) == len(set(stub_sites)) and set(stub_sites) == polls, 'poll/stub saved-site correspondence differs')
    require(slow_targets == stubs, 'poll branches do not target associated return stubs')
    return h,polls

def check(elf,fn,desc_at,disassembly,witness,mutation,report):
    mi = elf.names['.cjmetadata.methodinfo']
    desc = elf.bytes(mi)
    require(struct.unpack_from('<I',desc,desc_at+40)[0] == 0x31514a43, 'missing descriptor qualification tag')
    require(elf.relative(mi,desc_at+32) == (fn['section'],fn['value']), 'descriptor entry association mismatch')
    require(struct.unpack_from('<I',desc,desc_at+4)[0] == fn['size'], 'descriptor extent differs from symbol')
    qual = elf.relative(mi,desc_at+36)
    require(qual is not None and qual[0] == elf.names['.cjmetadata.stackmap'], 'qualification association absent')
    maps_data = elf.bytes(qual[0])
    at = qual[1]
    require(at+16 <= len(maps_data), 'qualification header truncated')
    magic,length,trans,sites = struct.unpack_from('<IIII',maps_data,at)
    require(magic == 0x31514a43 and length == 16+8*(trans+sites) and at+length <= len(maps_data), 'qualification bounds invalid')
    records = [list(struct.unpack_from('<IHH',maps_data,at+16+8*trans+8*i)) for i in range(sites)]
    # This bounded witness excludes kind2/patched/special stub events. Never
    # call them hardware calls or grant them implicit FULL layout semantics.
    require(all(kind in (1,3) for pc,kind,bits in records), 'UNRESOLVED_SAVED_EVENT: kind2 stub route')
    require(len({(pc,kind) for pc,kind,bits in records}) == len(records), 'duplicate site')
    ins = instructions(elf,disassembly,fn)
    h,r = hardware_and_return(elf,fn,ins)
    graph_at = elf.relative(mi,desc_at)
    graph = {'state':'absent','rows':{}}
    if graph_at:
        require(graph_at[0] == qual[0] and graph_at[1] < at, 'graph/qualification range association invalid')
        graph = decode_graph(maps_data[graph_at[1]:at])
    flag = struct.unpack_from('<I',desc,desc_at+28)[0]
    require(witness.get('function') == fn['name'] and witness.get('source_sha256'), 'independent input witness missing')
    source = Path(witness['source_path']).read_bytes()
    require(hashlib.sha256(source).hexdigest() == witness['source_sha256'], 'input witness identity differs')
    require(re.search(r'define\s+void\s+@'+re.escape(fn['name'])+r'\(', source.decode()), 'UNRESOLVED_RETURN_ABI: bounded executed witness requires void return')
    require(witness.get('return_poll_required') in (True,False), 'return eligibility witness unresolved')
    expected_flag = int(witness['return_poll_required'])
    rootmask = witness.get('return_root_mask')
    require(rootmask == 0, 'UNRESOLVED_RETURN_ABI: nonempty roots require actual ABI lowering witness')
    if mutation:
        returns = [row for row in records if row[1] == 3]
        require(returns, 'mutation target return not reached')
        if mutation == 'pc':
            returns[0][0] += 1
        elif mutation == 'bits':
            returns[0][2] = 1
        elif mutation == 'flag':
            flag ^= 1
        elif mutation == 'root':
            require(r and next(iter(r)) in graph['rows'], 'mutation root target absent')
            graph['rows'][next(iter(r))]['register_mask'] ^= 1
    report.update({'owner':fn,'H':sorted(h),'R':sorted(r),'S_status':'not in bounded ordinary witness',
                   'Q':records,'flag':flag,'expected_flag':expected_flag,'graph':graph,
                   'return_root_mask_expected':rootmask,'mutation':mutation})
    def assertion(axis,condition,detail):
        report.setdefault('assertions',[]).append({'axis':axis,'reached':True,'passed':bool(condition),'detail':detail})
    callers = {pc for pc,kind,bits in records if kind == 1}
    returns = {pc for pc,kind,bits in records if kind == 3}
    assertion('caller_pc',callers == h,{'Q_minus_H':sorted(callers-h),'H_minus_Q':sorted(h-callers)})
    assertion('return_pc',returns == r,{'Q_minus_R':sorted(returns-r),'R_minus_Q':sorted(r-returns)})
    assertion('return_bits',all(bits == 0 for pc,kind,bits in records if kind == 3), 'kind3 layout bits must be zero')
    assertion('return_flag',flag == expected_flag and bool(r) == bool(expected_flag), 'object polls/stub route and source eligibility agree')
    roots_ok = True
    root_detail = []
    for pc in sorted(r):
        g = graph['rows'].get(pc)
        ok = g is not None and g['register_mask'] == rootmask and all(g['indices'][i] == 0 for i in (1,3,4,5))
        roots_ok &= ok
        root_detail.append({'pc':pc,'state':'absent' if g is None else g['state'],'actual':None if g is None else g['register_mask'],'expected':rootmask})
    assertion('return_roots',roots_ok,root_detail)

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--object',required=True)
    p.add_argument('--object-sha256',required=True)
    p.add_argument('--objdump',required=True)
    p.add_argument('--objdump-sha256',required=True)
    p.add_argument('--witness',required=True)
    p.add_argument('--out',required=True)
    p.add_argument('--mutate',choices=['pc','bits','flag','root'])
    a = p.parse_args()
    report = {'status':'UNRESOLVED','checker_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'format_support':{'ELF':'bounded ELF64 ET_REL','COFF':'UNVERIFIED_NO_DECODER','MachO':'UNVERIFIED_NO_DECODER'}}
    rc = 2
    try:
        data = Path(a.object).read_bytes()
        report['object_sha256'] = hashlib.sha256(data).hexdigest()
        require(report['object_sha256'] == a.object_sha256, 'object identity differs')
        require(hashlib.sha256(Path(a.objdump).read_bytes()).hexdigest() == a.objdump_sha256, 'tool identity differs')
        witness = json.loads(Path(a.witness).read_text())
        require(witness.get('object_sha256') == report['object_sha256'], 'witness/object binding differs')
        elf = ELF(data)
        funcs = [f for f in elf.functions if f['name'] == witness.get('function')]
        require(len(funcs) == 1, 'function symbol association ambiguous')
        mi = elf.names.get('.cjmetadata.methodinfo')
        require(mi is not None, 'no methodinfo')
        associated = [at for at in range(0,len(elf.bytes(mi)),48) if elf.relative(mi,at+32) == (funcs[0]['section'],funcs[0]['value'])]
        require(len(associated) == 1, 'descriptor association ambiguous')
        d = subprocess.run([a.objdump,'-d',a.object],capture_output=True,text=True)
        report['objdump_command'] = d.args
        report['objdump_rc'] = d.returncode
        report['disassembly'] = d.stdout
        require(d.returncode == 0, 'disassembler failed: '+d.stderr)
        check(elf,funcs[0],associated[0],d.stdout,witness,a.mutate,report)
        report['status'] = 'PASS' if all(x['passed'] for x in report['assertions']) else 'FAIL'
        rc = int(report['status'] != 'PASS')
    except (Unresolved, OSError, ValueError, KeyError, struct.error) as e:
        report['error'] = str(e)
    report['rc'] = rc
    Path(a.out).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'status':report['status'],'rc':rc,'assertions':report.get('assertions',[]),'error':report.get('error')}),flush=True)
    return rc

if __name__ == '__main__':
    raise SystemExit(main())
