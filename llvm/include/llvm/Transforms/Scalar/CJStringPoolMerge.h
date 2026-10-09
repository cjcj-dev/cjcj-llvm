//===- CJStringPoolMerge.h - merge cangjie string literal pools -*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This pass merges the per-string cjstring data buffers that CodeGen emits
// (deferred pooling) into one shared pool, deduplicating identical strings.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJ_STRING_POOL_MERGE_H
#define LLVM_TRANSFORMS_SCALAR_CJ_STRING_POOL_MERGE_H

#include "llvm/IR/PassManager.h"

namespace llvm {
// Query the existing pool selection without changing the layout. A deferred
// buffer that will be repointed must have valid zero-start views, including
// every other record sharing that buffer. Skipped buffers keep their layout.
bool hasSafeCJStringPoolViews(GlobalVariable &Buffer);

struct CJStringPoolMerge : public PassInfoMixin<CJStringPoolMerge> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) const;
};
} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_CJ_STRING_POOL_MERGE_H
