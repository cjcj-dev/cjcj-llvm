#!/usr/bin/env python3
import concurrent.futures, hashlib, json, os, pathlib, re, shlex, shutil, subprocess, sys, time
root=pathlib.Path('/root/sym_cjcj_llvm_1_implement_r5668195885')
arm=sys.argv[1]
old=pathlib.Path('/root/sym_cangjie_runtime_560b_sym_cangjie_runtime_564_implement_r5664061027')
sdk=old/'gate-sdk'
bindir=(sdk/'third_party/llvm/bin') if arm=='baseline' else root/arm/'build/bin'
env=os.environ.copy()
env['LD_LIBRARY_PATH']=f'{old}/host/runtime/lib/linux_x86_64_cjnative:{sdk}/tools/lib:{old}/host/third_party/llvm/lib'
outroot=root/arm/'replay'
outroot.mkdir(exist_ok=True)
def runlevel(level):
    before=time.monotonic()
    base=root/'baseline/probe'/level
    dst=outroot/level
    dst.mkdir(exist_ok=True)
    subprocess.run(['uptime'],stdout=(dst/'uptime-before.txt').open('w'))
    shutil.copytree(base/'temps',dst/'temps',dirs_exist_ok=True)
    cmds=[]
    for line in (base/'compile.log').read_text().splitlines():
        if not (line.startswith("LD_LIBRARY_PATH=") or line.startswith("'/usr/bin/ld'") or (line.startswith("'") and "llvm-objcopy'" in line)):
            continue
        argv=shlex.split(line)
        if argv[0].startswith('LD_LIBRARY_PATH='):
            argv.pop(0)
        if pathlib.Path(argv[0]).name not in ('opt','llc','ld','llvm-objcopy'):
            continue
        argv=[a.replace(str(base),str(dst)) for a in argv]
        if pathlib.Path(argv[0]).name in ('llc','opt'):
            argv[0]=str(bindir/pathlib.Path(argv[0]).name)
        cmds.append(argv)
    receipts=[]
    with (dst/'replay.log').open('w') as log:
        for argv in cmds:
            log.write(shlex.join(argv)+'\n');log.flush()
            r=subprocess.run(argv,stdout=log,stderr=log,env=env)
            receipts.append({'argv':argv,'rc':r.returncode})
            if r.returncode:
                break
    (dst/'commands.json').write_text(json.dumps(receipts,indent=2)+'\n')
    rc=receipts[-1]['rc'] if receipts and len(receipts)==len(cmds) else 99
    (dst/'compile.rc').write_text(str(rc)+'\n')
    if rc==0:
        elf=dst/'global_slot_probe'
        (dst/'elf.sha256').write_text(hashlib.sha256(elf.read_bytes()).hexdigest()+'  '+str(elf)+'\n')
        for argv,name in [(['objdump','-drC',str(elf)],'disassembly'),(['nm','--defined-only',str(elf)],'defined')]:
            with (dst/(name+'.txt')).open('w') as f:
                r=subprocess.run(argv,stdout=f,stderr=subprocess.PIPE)
            (dst/(name+'.rc')).write_text(str(r.returncode)+'\n')
        for bc in (dst/'temps').glob('*.bc'):
            r=subprocess.run([str(root/'green/build/bin/llvm-dis'),str(bc),'-o',str(bc.with_suffix('.ll'))])
            if r.returncode: raise RuntimeError('llvm-dis failed')
    subprocess.run(['uptime'],stdout=(dst/'uptime-after.txt').open('w'))
    (dst/'wall.txt').write_text(str(time.monotonic()-before)+'\n')
    return level,rc
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results=list(pool.map(runlevel,['O0','O2']))
(outroot/'summary.json').write_text(json.dumps(results)+'\n')
files=[bindir/'llc',bindir/'opt',sdk/'bin/cjc',old/'host/runtime/lib/linux_x86_64_cjnative/libcangjie-runtime.so',old/'host/runtime/lib/linux_x86_64_cjnative/libboundscheck.so']
(outroot/'inputs.sha256').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+str(f)+'\n' for f in files))
print(arm,results)
