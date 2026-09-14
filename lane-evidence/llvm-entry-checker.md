LANE=sym_cjcj_llvm_1_implement_r5668195885
ROLE=implement
PROGRESS=WIP
已按上一答复执行 LLVM entry_cut_check。实测两刀都 rc=2，提示 invalid device path:sym entry: llvm/lib/CodeGen/CJBarrierLowering.cpp:GCPhaseCheck::SplitFastPathAndSlowPath。指定 PHASE_ENTRIES-llvm.txt 中 C++ qualified 名不被工具接受，且工具 device path family 是否允许 llvm/lib 需核。请主控修正工具/清单或明确替代证据，不由实现棒改 tools 范围。切刀文件在本工作树 lane-evidence/producer.diff 与 consumer.diff：producer 改基线既有 fastBarrierInline 中 GCPhase.fastBarrier(IID,CI) 调用，把 static 输入交给旧拆分路径（保留非 static 保护）；consumer 改基线 replaceInstWithBarrier 内 getOrInsertRuntimeFunc 调用，static 分支改为 raw store/memcpy。两刀不会修改候选新增行，也不动测试。
