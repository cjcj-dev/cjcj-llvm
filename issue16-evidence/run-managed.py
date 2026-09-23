import subprocess,os,hashlib,json,time,concurrent.futures
from pathlib import Path
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(arm):
    out=r/'managed'/arm;sdk=r/('sdk-'+arm);lib=sdk/'runtime/lib/linux_x86_64_cjnative'
    env=os.environ.copy();env['LD_LIBRARY_PATH']=str(lib)+':'+str(sdk/'lib/linux_x86_64_cjnative');env['CJ_HEAP_SIZE']='256MB'
    elf=out/'roundtrip';results=[]
    (out/'uptime-before.txt').write_bytes(subprocess.check_output(['uptime']))
    identity={'elf':sha(elf),'runtime':sha(lib/'libcangjie-runtime.so'),'boundscheck':sha(lib/'libboundscheck.so'),'cores':'0-3','runtime_source':'/root/sodepot/b7c19036dd611911a4fe050c3d4e8a74f9130c88','compiler':sha(sdk/'bin/cjcj-stage1'),'llc':sha(sdk/'bin/llc'),'opt':sha(sdk/'bin/opt'),'ldd':subprocess.run(['ldd',str(elf)],env=env,capture_output=True,text=True).stdout}
    (out/'run-identity.json').write_text(json.dumps(identity,indent=2))
    for i in range(3):
        start=time.monotonic()
        p=subprocess.run(['taskset','-c','0-3',str(elf)],env=env,capture_output=True,text=True,timeout=30)
        (out/f'run-{i}.log').write_text(p.stdout+p.stderr)
        results.append({'rc':p.returncode,'output':p.stdout,'target_assertion':'B3_READBACK=3736' in p.stdout,'wall':time.monotonic()-start})
    (out/'uptime-after.txt').write_bytes(subprocess.check_output(['uptime']))
    (out/'run-results.json').write_text(json.dumps(results,indent=2))
    print(arm,results)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    list(pool.map(run,['baseline','candidate']))
