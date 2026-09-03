//===- CJTypedReadHelper.cpp - typed aggregate read rewrite -----*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/CJTypedReadHelper.h"

#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/SafepointIRVerifier.h"
#include "llvm/Transforms/Scalar/CJFillMetadata.h"

using namespace llvm;

namespace {

struct TypedReadMatch {
  MemTransferInst *Copy;
  Value *Base;
  Value *Source;
  AllocaInst *Destination;
  uint64_t Size;
};

static StructType *layoutForAllocation(CallBase *Allocation) {
  if (!Allocation || Allocation->arg_size() < 2)
    return nullptr;
  auto *TI = dyn_cast<GlobalVariable>(
      Allocation->getArgOperand(0)->stripPointerCasts());
  if (!TI)
    return nullptr;
  return getTypeLayoutType(TI);
}

static bool isEntryAllocaDestination(Value *Ptr, const DataLayout &DL,
                                     AllocaInst *&AI) {
  auto *PT = dyn_cast<PointerType>(Ptr->getType());
  if (!PT || PT->getAddressSpace() != 0)
    return false;
  APInt Offset(DL.getIndexSizeInBits(0), 0);
  Value *Base = Ptr->stripAndAccumulateConstantOffsets(DL, Offset, true);
  AI = dyn_cast<AllocaInst>(Base);
  if (!AI || !Offset.isZero() ||
      AI->getParent() != &AI->getFunction()->getEntryBlock())
    return false;
  Type *T = AI->getAllocatedType();
  return T->isSized();
}

// Recover a source carrier and its managed-object base.  Casts and constant
// GEPs are accepted, but PHI/select/inttoptr/opaque call roots are not.
static bool recoverSource(Value *Ptr, const DataLayout &DL, Value *&Base,
                          Type *&PayloadTy, uint64_t &Offset) {
  auto *PT = dyn_cast<PointerType>(Ptr->getType());
  if (!PT || PT->getAddressSpace() != 1)
    return false;

  APInt APOffset(DL.getIndexSizeInBits(1), 0);
  Value *Root = Ptr->stripAndAccumulateConstantOffsets(DL, APOffset, true);
  auto *CB = dyn_cast<CallBase>(Root);
  if (!CB)
    return false;
  Intrinsic::ID IID = CB->getIntrinsicID();
  bool KnownAllocation = IID == Intrinsic::cj_malloc_object ||
                         IID == Intrinsic::cj_malloc_array ||
                         IID == Intrinsic::cj_alloca_generic;
  bool ManagedCall = !KnownAllocation && IID == Intrinsic::not_intrinsic &&
                     CB->getCalledFunction() &&
                     CB->getCalledFunction()->hasCangjieGC();
  if (!KnownAllocation && !ManagedCall)
    return false;

  Type *Ty = KnownAllocation ? layoutForAllocation(CB) : nullptr;
  if (!Ty) {
    if (auto *BC = dyn_cast<BitCastOperator>(Ptr)) {
      Type *SrcTy = BC->getSrcTy();
      if (auto *SrcPT = dyn_cast<PointerType>(SrcTy))
        if (!SrcPT->isOpaque() && SrcPT->getAddressSpace() == 1)
          Ty = SrcPT->getNonOpaquePointerElementType();
    }
  }
  if (!Ty || !Ty->isSized())
    return false;
  if (APOffset.isNegative() || APOffset.getActiveBits() > 64)
    return false;

  Base = Root;
  PayloadTy = Ty;
  Offset = APOffset.getZExtValue();
  return true;
}

static Optional<TypedReadMatch> matchTypedRead(MemTransferInst &MI,
                                               const DataLayout &DL) {
  if (MI.isVolatile() || MI.getDestAddressSpace() != 0 ||
      MI.getSourceAddressSpace() != 1)
    return None;
  auto *SizeCI = dyn_cast<ConstantInt>(MI.getLength());
  if (!SizeCI || SizeCI->isZero() || SizeCI->getBitWidth() > 64)
    return None;

  AllocaInst *AI = nullptr;
  if (!isEntryAllocaDestination(MI.getRawDest(), DL, AI))
    return None;

  Value *Base = nullptr;
  Type *PayloadTy = nullptr;
  uint64_t Offset = 0;
  if (!recoverSource(MI.getRawSource(), DL, Base, PayloadTy, Offset))
    return None;

  uint64_t Size = SizeCI->getZExtValue();
  TypeSize PayloadSize = DL.getTypeAllocSize(PayloadTy);
  if (PayloadSize.isScalable() || PayloadSize.getFixedSize() != Size ||
      !containsGCPtrType(PayloadTy))
    return None;

  // Every accepted root names a managed object base.  A read helper must start
  // exactly after its one-word header and cover the complete typed payload;
  // an uncontracted interior span is never a helper candidate.
  Intrinsic::ID IID = dyn_cast<CallBase>(Base)->getIntrinsicID();
  uint64_t Header = DL.getTypeAllocSize(Type::getInt8PtrTy(MI.getContext()))
                        .getFixedSize();
  if (Offset != Header)
    return None;
  if (IID == Intrinsic::cj_malloc_object ||
      IID == Intrinsic::cj_alloca_generic) {
    auto *AllocSize =
        dyn_cast<ConstantInt>(dyn_cast<CallBase>(Base)->getArgOperand(1));
    if (!AllocSize || AllocSize->getZExtValue() != Size)
      return None;
  } else if (IID == Intrinsic::cj_malloc_array) {
    // Array payloads require a typed element carrier; an erased array span is
    // intentionally left for the dedicated array barrier path.
    if (!dyn_cast<BitCastOperator>(MI.getRawSource()))
      return None;
  }

  if (AI->getAllocatedType() != PayloadTy)
    return None;
  return TypedReadMatch{&MI, Base, MI.getRawSource(), AI, Size};
}

static bool rewriteModule(Module &M) {
  SmallVector<TypedReadMatch, 8> Matches;
  const DataLayout &DL = M.getDataLayout();
  for (Function &F : M)
    for (Instruction &I : instructions(F))
      if (auto *MI = dyn_cast<MemTransferInst>(&I))
        if (auto Match = matchTypedRead(*MI, DL))
          Matches.push_back(*Match);
  if (Matches.empty())
    return false;

  for (TypedReadMatch Match : Matches) {
    IRBuilder<> B(Match.Copy);
    Function *Decl = Intrinsic::getDeclaration(
        &M, Intrinsic::cj_gcread_struct,
        {Match.Copy->getLength()->getType()});
    auto *Call = B.CreateCall(
        Decl, {Match.Copy->getRawDest(), Match.Base, Match.Source,
               Match.Copy->getLength()});
    Call->setDebugLoc(Match.Copy->getDebugLoc());
    Match.Copy->eraseFromParent();
  }
  return true;
}

} // namespace

bool llvm::isCJTypedReadHelperCandidate(MemTransferInst &Copy,
                                        const DataLayout &DL) {
  return matchTypedRead(Copy, DL).hasValue();
}

PreservedAnalyses
CJTypedReadHelper::run(Module &M, ModuleAnalysisManager &) const {
  return rewriteModule(M) ? PreservedAnalyses::none() : PreservedAnalyses::all();
}
