//===- CJInstanceOfOpt.h - --------------------------------------*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This file provides interface to "Cangjie Generic Intrinsic of Optimize" pass.
//
// This pass mainly implements the generic intrinsics optimization of cangjie.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJ_GENERIC_INTRINSIC_OPT_H
#define LLVM_TRANSFORMS_SCALAR_CJ_GENERIC_INTRINSIC_OPT_H

#include "llvm/IR/PassManager.h"

namespace llvm {
class Function;

// Propagate already-live generic metadata across internal direct calls before
// lowering erases the type-expression intrinsics. No runtime call is CSEd.
struct CJTypeInfoContext : public PassInfoMixin<CJTypeInfoContext> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) const;
};

struct CJGenericIntrinsicOpt : public PassInfoMixin<CJGenericIntrinsicOpt> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &) const;
};
} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_CJ_GENERIC_INTRINSIC_OPT_H
