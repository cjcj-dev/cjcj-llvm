//===- SafepointIRVerifier.h - Checks for GC relocation problems *- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines a verifier which is useful for enforcing the relocation
// properties required by a relocating GC.  Specifically, it looks for uses of
// the unrelocated value of pointer SSA values after a possible safepoint. It
// attempts to report no false negatives, but may end up reporting false
// positives in rare cases (see the note at the top of the corresponding cpp
// file.)
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_SAFEPOINTIRVERIFIER_H
#define LLVM_IR_SAFEPOINTIRVERIFIER_H

#include "llvm/ADT/SmallSet.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/PassManager.h"

namespace llvm {

class Function;
class FunctionPass;

/// Run the safepoint verifier over a single function.  Crashes on failure.
void verifySafepointIR(Function &F);

/// Create an instance of the safepoint verifier pass which can be added to
/// a pass pipeline to check for relocation bugs.
FunctionPass *createSafepointIRVerifierPass();

/// Create an instance of the safepoint verifier pass which can be added to
/// a pass pipeline to check for relocation bugs.
class SafepointIRVerifierPass : public PassInfoMixin<SafepointIRVerifierPass> {

public:
  explicit SafepointIRVerifierPass() = default;

  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);
};

/// TODO: Once we can get to the GCStrategy, this becomes
/// Optional<bool> isGCManagedPointer(const Type *Ty) const override {
bool isGCPointerType(Type *T);

/// Return true if this base is a gc pointer type.
bool isGCPtr(Value *V);

/// Returns true if this type contains a gc pointer whether we know how to
/// handle that type or not.
bool containsGCPtrType(Type *Ty);

/// Return true if this type is one which a) is a gc pointer or contains a GC
/// pointer and b) is of a type this code expects to encounter as a live value.
/// (The insertion code will assert that a type which matches (a) and not (b)
/// is not encountered.)
bool isHandledGCPointerType(Type *T);

/// Return true if a stack var pointer to gc ref or a struct var on stack
/// contains gc ref.
bool isMemoryContainsGCPtrType(Type *T);

Value *findMemoryBasePointer(Value *V);

/// Strip colour bits from addrspace(1) pointers (low 48 bits = AddressMask).
/// No-op for non-AS1 pointers. Shared by createStoreOrMems fastpath places,
/// bare MemTransferInst operands (mmstrip), and non-heap AS1 load/store
/// (STACK_ROOTS_STAY_PLAIN value-struct fields).
Value *uncolorIfGCPtr(Value *Ptr, IRBuilder<> &Builder);

Instruction *createStoreOrMems(CallBase *CI, IRBuilder<> &Builder);

bool isCJWriteBarrierIntrinsic(Intrinsic::ID IID);
bool isCJReadBarrierIntrinsic(Intrinsic::ID IID);
bool isCJMemcpyIntrinsic(Intrinsic::ID IID);
bool isCJAtomicIntrinsic(Intrinsic::ID IID);
bool isSafepointCall(CallBase *CB);
bool isInt8AS1Pty(Type *Ty);
bool isInt8AS0Pty(Value *Ptr);
bool maybeCJFinalizerObj(Value *V);
Type *getUniqueActualType(Value *V);
StructType *getLastStructTypeContain(Value *V);
void getAllStructTypes(Value *V, SmallSet<StructType *, 8> &STs);
}

#endif // LLVM_IR_SAFEPOINTIRVERIFIER_H
