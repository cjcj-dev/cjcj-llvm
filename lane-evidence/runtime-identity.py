import hashlib,pathlib,subprocess,json
root=pathlib.Path('/root/sym_cjcj_llvm_1_implement_r5668195885')
out=root/'runtime-evidence';out.mkdir(exist_ok=True)
so=pathlib.Path('/root/sym_cangjie_runtime_560b_sym_cangjie_runtime_564_implement_r5664061027/gate-sdk/runtime/lib/linux_x86_64_cjnative/libcangjie-runtime.so')
(out/'runtime.sha256').write_text(hashlib.sha256(so.read_bytes()).hexdigest()+'  '+str(so)+'\n')
r=subprocess.run(['nm','--defined-only',str(so)],capture_output=True,text=True)
(out/'nm.stderr').write_text(r.stderr);(out/'defined.nm').write_text(r.stdout);(out/'nm.rc').write_text(str(r.returncode)+'\n')
assert r.returncode==0
symbols=[]
for line in r.stdout.splitlines():
    fields=line.split()
    if len(fields)==3 and any(x in fields[2] for x in ['WriteStaticRef','WriteStaticStruct','WriteReferenceImpl','AtomicWriteReferenceImpl','NativeStoreBarrier']):
        symbols.append(fields[2])
for i,s in enumerate(symbols):
    r=subprocess.run(['objdump','-drC',f'--disassemble={s}',str(so)],capture_output=True,text=True)
    # GNU objdump -C expects demangled names for --disassemble; use mangled mode.
    r=subprocess.run(['objdump','-dr',f'--disassemble={s}',str(so)],capture_output=True,text=True)
    (out/f'symbol-{i}.asm').write_text(r.stdout)
    assert r.returncode==0
(out/'symbols.json').write_text(json.dumps(symbols,indent=2)+'\n')
print('runtime symbols',len(symbols))
