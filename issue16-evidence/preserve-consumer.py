from pathlib import Path
import shutil
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149')
(r/'consumer/bin').mkdir(parents=True,exist_ok=True)
for name in ['llc','opt','FileCheck']:
    shutil.copy2(r/'candidate/bin'/name,r/'consumer/bin'/name)
for p in r.glob('candidate-*'):
    if p.is_file(): shutil.copy2(p,r/p.name.replace('candidate-','consumer-',1))
shutil.copy2(r/'candidate.sha256',r/'consumer.sha256')
