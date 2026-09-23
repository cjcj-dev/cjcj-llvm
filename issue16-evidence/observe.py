import subprocess,hashlib,json,time,os,sys,concurrent.futures
from pathlib import Path
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149');out=r/'observations';out.mkdir(exist_ok=True)
fc=r/'green/bin/FileCheck'
sources=sorted((r/'llvm/test/CodeGen/X86/CangjieGC').glob('heap-domain-*.ll'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(job):
    arm,tool,src,level=job
    folder=out/arm;folder.mkdir(exist_ok=True)
    name=src.stem+'-'+level;start=time.monotonic()
    p=subprocess.run([str(tool),'--cangjie-pipeline','-mtriple=x86_64','-'+level,'-verify-machineinstrs','-print-after=cj-barrier-lowering','-o','/dev/null',str(src)],capture_output=True)
    ir=p.stdout+p.stderr;(folder/(name+'.ir')).write_bytes(ir)
    q=subprocess.run([str(fc),str(src)],input=ir,capture_output=True)
    (folder/(name+'.check.log')).write_bytes(q.stdout+q.stderr)
    # Only the actual probe body is counted, excluding wrapper functions/declarations.
    text=ir.decode();probe=text.split('define ',1)[1].split('\n}',1)[0] if 'define ' in text else ''
    return {'arm':arm,'name':src.name,'level':level,'llc_rc':p.returncode,'check_rc':q.returncode,'range_loads':sum('load i64, i64* @g_cjHeapRangeCount' in line for line in probe.splitlines()),'mask_reads':sum(('cj.storebadmask = load' in line or 'cj.loadbadmask = load' in line) for line in probe.splitlines()),'wall':time.monotonic()-start}
jobs=[]
for arm in sys.argv[1:]:
    tool=r/({'consumer':'candidate','restored':'candidate'}.get(arm,arm))/'bin/llc'
    folder=out/arm;folder.mkdir(exist_ok=True)
    (folder/'uptime-before.txt').write_bytes(subprocess.check_output(['uptime']))
    ident={'llc_sha256':sha(tool),'filecheck_sha256':sha(fc),'input_sha256':{s.name:sha(s) for s in sources},'jobs':os.cpu_count()}
    (folder/'identity.json').write_text(json.dumps(ident,indent=2))
    jobs.extend((arm,tool,s,level) for s in sources for level in ['O0','O2'])
start=time.monotonic()
with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
    all_rows=list(pool.map(run,jobs))
for arm in sys.argv[1:]:
    rows=[x for x in all_rows if x['arm']==arm];folder=out/arm
    (folder/'results.json').write_text(json.dumps({'wall':time.monotonic()-start,'rows':rows},indent=2))
    (folder/'uptime-after.txt').write_bytes(subprocess.check_output(['uptime']))
    print(arm,'N',len(rows),'llc failures',sum(x['llc_rc']!=0 for x in rows),'check failures',sum(x['check_rc']!=0 for x in rows))
