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

// An erased payload may be copied from an element inside an AS0 buffer.  The
// helper only needs a readable source range; unlike an AS1 heap slot, this
// source has no managed-reference provenance that would require read-side
// healing.  Keep the root deliberately narrow so a loaded, computed, or
// otherwise interior pointer cannot accidentally be treated as a native
// buffer supplied by the frontend.
static bool isAllowedElementSource(Value *Source) {
  auto *GEP = dyn_cast<GetElementPtrInst>(Source);
  if (!GEP || !GEP->isInBounds() || GEP->getNumIndices() != 1 ||
      GEP->getSourceElementType() !=
          Type::getInt8Ty(Source->getContext()) ||
      !GEP->idx_begin()->get()->getType()->isIntegerTy(64))
    return false;

  auto *BaseTy = dyn_cast<PointerType>(GEP->getPointerOperand()->getType());
  if (!BaseTy || BaseTy->getAddressSpace() != 0)
    return false;

  Value *Base = GEP->getPointerOperand();
  if (isa<Argument>(Base))
    return true;

  auto *Alloca = dyn_cast<AllocaInst>(Base);
  return Alloca &&
         Alloca->getParent() == &Alloca->getFunction()->getEntryBlock();
}

// Source addressing may be wrapped in one or more bitcasts and GEPs.  The
// barrier may only consume a source whose underlying storage is supplied by a
// function argument or an entry-block alloca; a load or another instruction
// does not establish that provenance.
static bool hasAllowedSourceRoot(Value *Source) {
  while (true) {
    if (auto *Cast = dyn_cast<BitCastInst>(Source)) {
      Source = Cast->getOperand(0);
      continue;
    }
    if (auto *GEP = dyn_cast<GetElementPtrInst>(Source)) {
      Source = GEP->getPointerOperand();
      continue;
    }
    break;
  }

  if (isa<Argument>(Source))
    return true;

  auto *Alloca = dyn_cast<AllocaInst>(Source);
  return Alloca &&
         Alloca->getParent() == &Alloca->getFunction()->getEntryBlock();
}

static Optional<BoxedPayloadCopy> matchBoxedPayloadCopy(Instruction &I) {
  auto *Copy = dyn_cast<MemCpyInst>(&I);
  if (!Copy || Copy->isVolatile() || Copy->getDestAddressSpace() != 1 ||
      Copy->getSourceAddressSpace() != 0 ||
      !Copy->getLength()->getType()->isIntegerTy(32) ||
      isa<ConstantInt>(Copy->getLength()))
    return None;

  Value *Source = Copy->getRawSource();
  if (isa<GetElementPtrInst>(Source) && !isAllowedElementSource(Source))
    return None;
  if (!hasAllowedSourceRoot(Source))
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

  // Allocation and the header GEP/bitcast remain an adjacent destination
  // chain.  The frontend may compute an AS0 element address between the
  // header GEP and the final payload bitcast (for example zext/mul/GEP), so
  // that one source-side gap is intentionally not required to be adjacent.
  // The payload bitcast itself must still immediately precede the copy.
  if (Copy->getPrevNonDebugInstruction() != PayloadCast ||
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
