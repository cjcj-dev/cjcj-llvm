from pathlib import Path
import shutil
r=Path('/root/sym_cjcj_llvm_16_implement_r5788821149')
source=Path('/root/sdkdepot/b99430a618af-1ecb811801ca')
so=Path('/root/sodepot/b7c19036dd611911a4fe050c3d4e8a74f9130c88')
for arm in ['baseline','candidate']:
    dest=r/('sdk-'+arm)
    shutil.copytree(source,dest,symlinks=False)
    for name in ['cjc','cjc-frontend']:
        p=dest/'bin'/name
        p.unlink()
        p.symlink_to('cjcj-stage1')
    for name in ['libcangjie-runtime.so','libboundscheck.so']:
        shutil.copy2(so/name,dest/'runtime/lib/linux_x86_64_cjnative'/name)
    for prefix in ['bin','third_party/llvm/bin']:
        for tool in ['llc','opt']:
            shutil.copy2(r/arm/'bin'/tool,dest/prefix/tool)
    shutil.copy2(so/'PROVENANCE.txt',dest/'B3-runtime-PROVENANCE.txt')
