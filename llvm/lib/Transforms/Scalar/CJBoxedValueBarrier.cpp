//===- CJBoxedValueBarrier.cpp - Boxed value barrier rewrite ---*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// A dynamically sized generic value is represented as plain bytes in AS0.
// The frontend boxes it using this exact, local sequence:
//
//   %object = call @llvm.cj.malloc.object(%typeInfo, %size)
//          or call @llvm.cj.alloca.generic(%typeInfo, %size)
//   %object.fields = bitcast %object to i8* addrspace(1)*
//   %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
//   %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
//   call @llvm.memcpy.p1i8.p0i8.i32(%payload, %source, %size, false)
//
// A plain memcpy cannot preserve managed-reference representation or record
// cross-generation edges when the erased payload contains references.  Rewrite
// only the closed sequence above to llvm.cj.gcwrite.generic.payload.  Requiring
// the four instructions to be consecutive is intentional: it proves that the
// new object cannot be published between allocation and initialization, and it
// keeps unrelated AS1 memcpy operations outside this pass.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/CJBoxedValueBarrier.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/Module.h"

using namespace llvm;

namespace {

struct BoxedPayloadCopy {
  MemCpyInst *Copy;
  CallInst *Allocation;
};

static Optional<BoxedPayloadCopy> matchBoxedPayloadCopy(Instruction &I) {
  auto *Copy = dyn_cast<MemCpyInst>(&I);
  if (!Copy || Copy->isVolatile() || Copy->getDestAddressSpace() != 1 ||
      Copy->getSourceAddressSpace() != 0 ||
      !Copy->getLength()->getType()->isIntegerTy(32) ||
      isa<ConstantInt>(Copy->getLength()))
    return None;

  auto *PayloadCast = dyn_cast<BitCastInst>(Copy->getRawDest());
  auto *PayloadGEP = PayloadCast
                         ? dyn_cast<GetElementPtrInst>(PayloadCast->getOperand(0))
                         : nullptr;
  auto *ObjectCast = PayloadGEP
                         ? dyn_cast<BitCastInst>(PayloadGEP->getPointerOperand())
                         : nullptr;
  auto *Allocation = ObjectCast
                         ? dyn_cast<CallInst>(ObjectCast->getOperand(0))
                         : nullptr;
  if (!PayloadCast || !PayloadGEP || !ObjectCast || !Allocation)
    return None;
  Intrinsic::ID AllocationID = Allocation->getIntrinsicID();
  if (AllocationID != Intrinsic::cj_malloc_object &&
      AllocationID != Intrinsic::cj_alloca_generic)
    return None;

  // The frontend's boxed payload is field 1 of an i8* field array.  This is an
  // exact one-pointer-width skip over the TypeInfo header, not a general
  // offset-based destination matcher.
  if (PayloadGEP->getSourceElementType() !=
          Type::getInt8PtrTy(I.getContext()) ||
      PayloadGEP->getNumIndices() != 1)
    return None;
  auto *PayloadIndex = dyn_cast<ConstantInt>(PayloadGEP->idx_begin()->get());
  if (!PayloadIndex || !PayloadIndex->isOne())
    return None;

  // The allocation and the destination derivation must be the immediately
  // preceding non-debug instructions.  Any intervening instruction could
  // publish the object or indicate a different frontend shape.
  if (Copy->getPrevNonDebugInstruction() != PayloadCast ||
      PayloadCast->getPrevNonDebugInstruction() != PayloadGEP ||
      PayloadGEP->getPrevNonDebugInstruction() != ObjectCast ||
      ObjectCast->getPrevNonDebugInstruction() != Allocation)
    return None;

  if (Allocation->arg_size() != 2 ||
      Allocation->getArgOperand(1) != Copy->getLength())
    return None;

  return BoxedPayloadCopy{Copy, Allocation};
}

static bool rewriteBoxedPayloadCopies(Module &M) {
  SmallVector<BoxedPayloadCopy, 4> Matches;
  for (Function &F : M)
    for (Instruction &I : instructions(F))
      if (Optional<BoxedPayloadCopy> Match = matchBoxedPayloadCopy(I))
        Matches.push_back(*Match);

  if (Matches.empty())
    return false;

  Function *Barrier = Intrinsic::getDeclaration(
      &M, Intrinsic::cj_gcwrite_generic_payload);
  for (BoxedPayloadCopy Match : Matches) {
    IRBuilder<> Builder(Match.Copy);
    CallInst *BarrierCall = Builder.CreateCall(
        Barrier, {Match.Allocation, Match.Copy->getRawSource(),
                  Match.Copy->getLength()});
    BarrierCall->setDebugLoc(Match.Copy->getDebugLoc());
    Match.Copy->eraseFromParent();
  }
  return true;
}

} // namespace

PreservedAnalyses
CJBoxedValueBarrier::run(Module &M, ModuleAnalysisManager &) const {
  if (!rewriteBoxedPayloadCopies(M))
    return PreservedAnalyses::all();
  return PreservedAnalyses::none();
}
