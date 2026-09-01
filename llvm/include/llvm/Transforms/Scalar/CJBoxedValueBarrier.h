//===- CJBoxedValueBarrier.h - Boxed value barrier rewrite -----*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This pass rewrites the exact frontend sequence which copies a dynamically
// sized generic value into the payload of a newly allocated boxed object.  The
// replacement uses the generic-payload write barrier so the runtime can decide
// whether the erased payload contains managed references.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJ_BOXED_VALUE_BARRIER_H
#define LLVM_TRANSFORMS_SCALAR_CJ_BOXED_VALUE_BARRIER_H

#include "llvm/IR/PassManager.h"

namespace llvm {
class Module;

struct CJBoxedValueBarrier : public PassInfoMixin<CJBoxedValueBarrier> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) const;
};
} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_CJ_BOXED_VALUE_BARRIER_H
