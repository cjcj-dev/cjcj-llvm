import subprocess,hashlib,json
from pathlib import Path
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149');b=r/'candidate'
p=b/'bin/llc';before=hashlib.sha256(p.read_bytes()).hexdigest()
commands=subprocess.check_output(['ninja','-t','commands','bin/llc'],cwd=b,text=True).splitlines()
command=commands[-1]
assert ' -o bin/llc ' in command
command=command.replace(' -o bin/llc ',' -Wl,-Map,'+str(r/'candidate-llc.map')+' -o bin/llc ',1)
(r/'link-map-command.txt').write_text(command+'\n')
rc=subprocess.call(command,cwd=b,shell=True)
after=hashlib.sha256(p.read_bytes()).hexdigest()
obj=b/'lib/CodeGen/CMakeFiles/LLVMCodeGen.dir/CJBarrierLowering.cpp.o'
nm=subprocess.run(['nm','--defined-only',str(obj)],capture_output=True,text=True)
(r/'candidate-object-nm.txt').write_text(nm.stdout+nm.stderr)
nme=subprocess.run(['nm','--defined-only',str(p)],capture_output=True,text=True)
(r/'candidate-elf-nm.txt').write_text(nme.stdout+nme.stderr)
(r/'link-map-identity.json').write_text(json.dumps({'rc':rc,'before':before,'after':after,'identical':before==after,'object_sha256':hashlib.sha256(obj.read_bytes()).hexdigest(),'object_nm_rc':nm.returncode,'elf_nm_rc':nme.returncode},indent=2))
print('link map',rc,'same tested ELF',before==after)
assert rc==0 and before==after
