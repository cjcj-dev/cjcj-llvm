//===- CJTypedCallReturnCopy.h - Typed native call copies ------*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This pass recognizes the exact frontend sequence which materializes a
// concrete CType value returned by a direct cj2c call.  It replaces only a
// whole-object copy into a same-typed entry alloca with a typed helper, so the
// Cangjie IR verifier need not infer pointee layout from an opaque call result.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJ_TYPED_CALL_RETURN_COPY_H
#define LLVM_TRANSFORMS_SCALAR_CJ_TYPED_CALL_RETURN_COPY_H

#include "llvm/IR/PassManager.h"

namespace llvm {
class Module;

struct CJTypedCallReturnCopy : public PassInfoMixin<CJTypedCallReturnCopy> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) const;
};
} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_CJ_TYPED_CALL_RETURN_COPY_H
