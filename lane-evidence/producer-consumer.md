坐标基于 1e806ee5489af1c9d23c1021798ff09b0d210742；修改前顺序表。
| producer | consumer | 修改必须落点 |
| fastBarrierInline static ref/struct 收集 CJBarrierLowering.cpp:956 | GCPhaseCheck::fastBarrier :373 -> setLastBarrier/Barriers.push_back :412 | 在入 Barriers 前拒绝 static 的相位拆分 |
| GCPhaseCheck::replaceBarrier :591 | SplitFastPathAndSlowPath :550 -> createFastInstr :507 | 旧代码把非空 ref 原始 store/struct memcpy 放在 gcNoRunning |
| CJBarrierLowering::doLowering :1049 | BarrierMaker::replaceInstWithBarrier :133 / static struct :163 / 默认 setCalledFunction :187 | 未被 phase 拆分的 intrinsic 无条件变为 CJ_MCC_WriteStaticRef/Struct |
| IntrinsicMap :62-63 | runtime CJ_MCC_WriteStaticRef/Struct | 本条只改 LLVM，runtime 着色消费需读实现与工具链 ELF 验证 |
ZGC: /root/cj_build/reference/jdk/src/hotspot/share/gc/z/zBarrierSet.inline.hpp:265 Raw::store(p, store_good(value)); :598 原子 cmpxchg 使用 store_good。
