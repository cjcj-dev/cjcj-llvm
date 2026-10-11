//===- CJRSSCE.cpp ----------------------------------------------*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This file provides interface to "CJ Redundant Stack Struct Copy Elimination"
// pass.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJRSSCE_H
#define LLVM_TRANSFORMS_SCALAR_CJRSSCE_H

#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/MemorySSA.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"

namespace llvm {

struct CJRSSCEPass : public PassInfoMixin<CJRSSCEPass> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);
};

/// Check all memory in the underlying objects of UnderObj. Callers retaining
/// several copy ranges or an unknown size must not bound this by a pointee type.
bool hasMemoryDefBetween(MemorySSA &MSSA, DominatorTree &DT,
                         const DataLayout &DL, Value *UnderObj,
                         Instruction *FirstI, MemoryAccess *LastMA,
                         bool LastClosure = true, bool EnableDiffBB = false);
} // namespace llvm

#endif
