//===- CJTypedCallReturnCopy.cpp - Typed native call copies ----*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// CPointer<T>.read currently materializes a concrete native structure as:
//
//   %native = call i8* @foreign()                       ; direct, "cj2c"
//   %typed = bitcast i8* %native to %T*
//   %zero = getelementptr %T, %T* %typed, i64 0
//   %source = bitcast %T* %zero to i8*
//   call @llvm.memcpy(entry-alloca(%T), %source, sizeof(%T), false)
//
// The call's opaque i8* return is intentionally not a trusted verifier root.
// Recover the type only from this closed frontend sequence, and preserve it on
// a typed helper.  Every condition below is part of the admission contract:
// AS0 on both sides, direct cj2c call, one zero GEP, typed operations in the
// copy block, named sized structure without AS1 fields, exact alloc size, and
// a same-typed static entry alloca at offset zero.  The call is either in that
// block or reaches it only through the unique null-check CFG recognized below.
// No general call-root verifier rule is changed.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/CJTypedCallReturnCopy.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/SafepointIRVerifier.h"

using namespace llvm;

namespace {

struct TypedCallReturnCopy {
  MemTransferInst *Copy;
  StructType *PayloadType;
};

static bool isZeroIndexGEP(const GetElementPtrInst *GEP, StructType *ST) {
  if (GEP->getSourceElementType() != ST || GEP->getNumIndices() != 1 ||
      GEP->getPointerAddressSpace() != 0)
    return false;
  auto *Index = dyn_cast<ConstantInt>(GEP->idx_begin()->get());
  return Index && Index->isZero();
}

static bool isNullComparison(const ICmpInst *Compare,
                             const PtrToIntInst *PointerAsInt) {
  if (!Compare || !PointerAsInt || !Compare->isEquality())
    return false;
  Value *Other = nullptr;
  if (Compare->getOperand(0) == PointerAsInt)
    Other = Compare->getOperand(1);
  else if (Compare->getOperand(1) == PointerAsInt)
    Other = Compare->getOperand(0);
  auto *Zero = dyn_cast_or_null<ConstantInt>(Other);
  return Zero && Zero->isZero();
}

// The production frontend separates a native call from CPointer<T>.read with
// a null check.  Admit only that one CFG shape: a ptrtoint-null comparison,
// exactly one conditional branch, then a single-predecessor/single-successor
// chain along the non-null edge.  Every other intervening instruction must be
// debug-only.  This structural walk makes the non-null successor dominate the
// copy without admitting a merge, a second condition, or side effects.
static bool hasPermittedCallToCopyPath(CallInst *NativeCall,
                                       Instruction *Copy) {
  BasicBlock *CallBlock = NativeCall->getParent();
  BasicBlock *CopyBlock = Copy->getParent();
  if (CallBlock == CopyBlock)
    return true;

  BasicBlock *Current = CallBlock;
  PtrToIntInst *PointerAsInt = nullptr;
  ICmpInst *NullCompare = nullptr;
  bool SawConditional = false;
  SmallPtrSet<BasicBlock *, 16> Visited;

  for (unsigned Depth = 0; Depth != 16; ++Depth) {
    if (!Visited.insert(Current).second)
      return false;
    if (Current == CopyBlock)
      return SawConditional;

    Instruction *Begin =
        Current == CallBlock ? NativeCall->getNextNode() : &Current->front();
    for (Instruction *I = Begin; I && I != Current->getTerminator();
         I = I->getNextNode()) {
      if (isa<DbgInfoIntrinsic>(I))
        continue;
      if (!SawConditional && !PointerAsInt) {
        auto *Candidate = dyn_cast<PtrToIntInst>(I);
        if (Candidate && Candidate->getPointerOperand() == NativeCall) {
          PointerAsInt = Candidate;
          continue;
        }
      }
      if (!SawConditional && !NullCompare) {
        auto *Candidate = dyn_cast<ICmpInst>(I);
        if (isNullComparison(Candidate, PointerAsInt)) {
          NullCompare = Candidate;
          continue;
        }
      }
      return false;
    }

    auto *Branch = dyn_cast<BranchInst>(Current->getTerminator());
    if (!Branch)
      return false;

    BasicBlock *Next = nullptr;
    if (Branch->isUnconditional()) {
      Next = Branch->getSuccessor(0);
    } else {
      if (SawConditional || !NullCompare ||
          Branch->getCondition() != NullCompare)
        return false;
      bool NonNullOnTrue =
          NullCompare->getPredicate() == ICmpInst::ICMP_NE;
      Next = Branch->getSuccessor(NonNullOnTrue ? 0 : 1);
      SawConditional = true;
    }

    // A unique incoming edge at every step is the explicit no-merge and
    // dominance proof.  It also keeps the null successor outside the copy
    // region.
    if (!Next || Next->getSinglePredecessor() != Current)
      return false;
    Current = Next;
  }
  return false;
}

static Optional<TypedCallReturnCopy>
matchTypedCallReturnCopy(Instruction &I, const DataLayout &DL) {
  auto *Copy = dyn_cast<MemTransferInst>(&I);
  if (!Copy || (Copy->getIntrinsicID() != Intrinsic::memcpy &&
                Copy->getIntrinsicID() != Intrinsic::memmove) ||
      Copy->isVolatile() || Copy->getDestAddressSpace() != 0 ||
      Copy->getSourceAddressSpace() != 0)
    return None;

  auto *Length = dyn_cast<ConstantInt>(Copy->getLength());
  if (!Length || Length->isZero())
    return None;

  // Source syntax is deliberately exact.  In particular, do not use a
  // generic stripPointerCasts walk here: it would also admit phi/select/load,
  // nonzero offsets, and unrelated type-punning chains.
  auto *SourceByteCast = dyn_cast<BitCastInst>(Copy->getRawSource());
  auto *SourceGEP = SourceByteCast
                        ? dyn_cast<GetElementPtrInst>(
                              SourceByteCast->getOperand(0))
                        : nullptr;
  auto *TypedCast = SourceGEP
                        ? dyn_cast<BitCastInst>(
                              SourceGEP->getPointerOperand())
                        : nullptr;
  auto *NativeCall =
      TypedCast ? dyn_cast<CallInst>(TypedCast->getOperand(0)) : nullptr;
  if (!SourceByteCast || !SourceGEP || !TypedCast || !NativeCall ||
      SourceByteCast->getParent() != Copy->getParent() ||
      SourceGEP->getParent() != Copy->getParent() ||
      TypedCast->getParent() != Copy->getParent() ||
      !hasPermittedCallToCopyPath(NativeCall, Copy))
    return None;

  auto *TypedPtr = dyn_cast<PointerType>(TypedCast->getType());
  auto *ST = TypedPtr && !TypedPtr->isOpaque()
                 ? dyn_cast<StructType>(
                       TypedPtr->getNonOpaquePointerElementType())
                 : nullptr;
  if (!ST || TypedPtr->getAddressSpace() != 0 || !ST->hasName() ||
      !ST->isSized() || containsGCPtrType(ST) ||
      !isZeroIndexGEP(SourceGEP, ST) ||
      NativeCall->getType() != Type::getInt8PtrTy(I.getContext()))
    return None;

  Function *Callee = NativeCall->getCalledFunction();
  if (!Callee || !Callee->hasFnAttribute("cj2c"))
    return None;

  TypeSize PayloadSize = DL.getTypeAllocSize(ST);
  if (PayloadSize.isScalable() ||
      Length->getValue().getActiveBits() > 64 ||
      Length->getZExtValue() != PayloadSize.getFixedSize())
    return None;

  // stripPointerCastsSameRepresentation admits only bitcasts and zero GEPs,
  // never an address-space round trip.  The alloca checks make this a complete
  // same-type object at offset zero, not an interior or differently typed sink.
  Value *DestinationBase =
      Copy->getRawDest()->stripPointerCastsSameRepresentation();
  auto *Destination = dyn_cast<AllocaInst>(DestinationBase);
  if (!Destination || !Destination->isStaticAlloca() ||
      Destination->isArrayAllocation() ||
      Destination->getAllocatedType() != ST)
    return None;

  return TypedCallReturnCopy{Copy, ST};
}

static bool rewriteTypedCallReturnCopies(Module &M) {
  SmallVector<TypedCallReturnCopy, 4> Matches;
  const DataLayout &DL = M.getDataLayout();
  for (Function &F : M)
    for (Instruction &I : instructions(F))
      if (Optional<TypedCallReturnCopy> Match =
              matchTypedCallReturnCopy(I, DL))
        Matches.push_back(*Match);

  if (Matches.empty())
    return false;

  for (TypedCallReturnCopy Match : Matches) {
    IRBuilder<> Builder(Match.Copy);
    Function *TypedCopy = Intrinsic::getDeclaration(
        &M, Intrinsic::cj_copy_no_ref_struct,
        {Match.Copy->getLength()->getType()});
    CallInst *TypedCall = Builder.CreateCall(
        TypedCopy, {Match.Copy->getRawDest(), Match.Copy->getRawSource(),
                    Match.Copy->getLength()});
    TypedCall->copyMetadata(*Match.Copy);
    TypedCall->setMetadata(
        LLVMContext::MD_cj_agg,
        MDNode::get(M.getContext(),
                    MDString::get(M.getContext(),
                                  Match.PayloadType->getName())));
    if (MaybeAlign DestAlign = Match.Copy->getDestAlign())
      TypedCall->addParamAttr(
          0, Attribute::getWithAlignment(M.getContext(), *DestAlign));
    if (MaybeAlign SourceAlign = Match.Copy->getSourceAlign())
      TypedCall->addParamAttr(
          1, Attribute::getWithAlignment(M.getContext(), *SourceAlign));
    TypedCall->setDebugLoc(Match.Copy->getDebugLoc());
    Match.Copy->eraseFromParent();
  }
  return true;
}

} // namespace

PreservedAnalyses
CJTypedCallReturnCopy::run(Module &M, ModuleAnalysisManager &) const {
  if (!rewriteTypedCallReturnCopies(M))
    return PreservedAnalyses::all();
  return PreservedAnalyses::none();
}
