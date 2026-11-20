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
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/StringSet.h"
#include <string>

namespace llvm {
class Function;
class CallInst;
class Module;
class Value;

// Per-opt-invocation facts. Export proofs deliberately do not use the owner
// map used for publishing roots: it also contains imports and ABI promises.
class CJWasmReturnBases {
  StringSet<> Imports;
  SmallPtrSet<const Function *, 8> ReceiverIdentities;
  std::string Exports;
  bool ExportEnabled = false;

public:
  static bool requested();
  static bool applies(const Module &M);
  explicit CJWasmReturnBases(Module &M, bool Enabled);
  bool imports(const CallInst &Call) const;
  bool receiverIdentity(const CallInst &Call) const;
  void collect(Function &F, ArrayRef<Value *> HeapObjects);
  void write() const;
};

// Publish live shadow roots or issue a compile error for unsupported IR.
bool emitCJWasmRoots(Function &F);
} // namespace llvm
#endif
