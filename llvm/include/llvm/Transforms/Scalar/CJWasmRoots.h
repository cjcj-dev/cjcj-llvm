//===- CJWasmRoots.h - WASI shadow root frames ------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The root pass of the wasm32-wasi managed ABI. It is the last IR pass of the
// Cangjie pipeline (I-BACKEND: only the code generator runs after it), so the
// liveness it computes is the liveness of the final IR.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJWASMROOTS_H
#define LLVM_TRANSFORMS_SCALAR_CJWASMROOTS_H

#include "llvm/IR/PassManager.h"

namespace llvm {
class Module;

struct CJWasmRootsPass : public PassInfoMixin<CJWasmRootsPass> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &AM);
};
} // namespace llvm

#endif
