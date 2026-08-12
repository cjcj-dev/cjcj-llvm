//===- ManagedABIGateVerifier.h - Cangjie managed ABI gate -----*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_MANAGED_ABI_GATE_VERIFIER_H
#define LLVM_TRANSFORMS_SCALAR_MANAGED_ABI_GATE_VERIFIER_H

#include "llvm/IR/PassManager.h"

namespace llvm {
class Module;

/// Report managed ABI values that cannot be proved to be plain and safe.
///
/// The pass is deliberately report-only. It never changes IR and is gated by
/// -managed-abi-gate-report-only, which is off by default.
struct ManagedABIGateVerifierPass
    : public PassInfoMixin<ManagedABIGateVerifierPass> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) const;
};
} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_MANAGED_ABI_GATE_VERIFIER_H
