//===- CJWasmRoots.h - Late wasm shadow roots -------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TRANSFORMS_SCALAR_CJWASMROOTS_H
#define LLVM_LIB_TRANSFORMS_SCALAR_CJWASMROOTS_H

#include "llvm/ADT/ArrayRef.h"

namespace llvm {
class Function;
class Module;
class Value;
bool checkCJWasmRootContract(Module &M);
bool emitCJWasmRoots(Function &F, ArrayRef<Value *> HeapObjects,
                     ArrayRef<Value *> StackObjects);
} // namespace llvm
#endif
