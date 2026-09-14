LANE=sym_cjcj_llvm_1_implement_r5668195885
ROLE=implement
PROGRESS=WIP
请裁定 LLVM 仓验证口径：指定 /root/cj_build/ops/bin/kkk2_build_two.sh 第9行强制存在 runtime/，本 LLVM 树不存在该目录；run_standalone/default/filler/OHOS 和 PHASE_ENTRIES.txt 也为 runtime 入口。建议本包使用 kkk2 LLVM Release 产品 opt/llc 的 lit + O0/O2 IR/汇编/ELF 三臂，生产侧恢复 static/atomic phase fastpath，消费侧切 BarrierMaker runtime call。请指定 LLVM 构建入口/可复用源码缓存与 LLVM entry_cut_check phase entries（或明确本包适用替代项）。冻结坐标回读 rc=0 为 1e806ee5489af1c9d23c1021798ff09b0d210742，候选 HEAD=b52b16b84057777fb7e0e6709d61711303f911e7；计划按任务明确 merge 主线接入，只有 origin(cjcj-dev/cjcj-llvm) remote，无 cjcjdev 别名，将添加等址别名。
