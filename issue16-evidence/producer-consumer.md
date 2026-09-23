待主控登记进 /root/cj_build/ops/CURRENT_DOCS.manifest。
坐标 5fc812a1d014deaf660d704a15dc0dc0a091788b。

| 顺序 | producer / consumer | 本包修改位置 |
|---|---|---|
| 1 | PEA 栈化，llvm/lib/Transforms/IPO/CJPartialEscapeAnalysis.cpp | 不依赖此前元数据 |
| 2 | gc.statepoint + gc.result，llvm/include/llvm/IR/IntrinsicInst.h:1452 | 仅认可实际分配调用 |
| 3 | CJBarrierLowering::runOnFunction:980 → doNewFastPath:859 → replaceFastFunc:841 | 证明须识别实际替换的 Fast 分配入口 |
| 4 | readBarrierFastPath:781 → ReadBarrier::readFastPath:413 → emitReservedHeapSlot:424 | 在发射动态查询之前证明 slot 来源 |
| 5 | WriteBarrier::storeFastPath:542 → emitReservedHeapSlot:562 | 在发射动态查询之前证明 slot 来源 |
| 6 | doLowering:796 → BarrierMaker::replaceInstWithBarrier | 未证实来源保留 runtime accessor |

ZGC 对应：zBarrierSet.cpp:229-241 barrier_needed 以静态存储域判定；c2/zBarrierSetC2.cpp:341-364 set_barrier_data 以 IN_NATIVE 静态分路。
基础设施差异：Cangjie 栈上对象/无头值记录在 AS1，故未证实来源保持既有 reservation 查询。
