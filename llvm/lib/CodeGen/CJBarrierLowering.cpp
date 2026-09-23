//===-- GCBarrierLowering.cpp - Cangjie Barrier Lowering ------------------===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This file implements the lowering for the cangjie barrier mechanism.
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/IR/CJIntrinsics.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/SafepointIRVerifier.h"
#include "llvm/IR/Statepoint.h"
#include "llvm/IR/CJStructTypeGCInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/MC/MCContext.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"

#include <unordered_map>

using namespace llvm;
using namespace cangjie;

#define DEBUG_TYPE "cj-barrier-lowering"

static cl::opt<bool> EnableTaggedPointer("enable-tagged-pointer",
                                         cl::init(true), cl::Hidden);
static cl::opt<bool> EnableGCFastPath("enable-gc-fast-path", cl::init(true),
                                      cl::Hidden);

namespace llvm {
extern cl::opt<bool> CangjieJIT;
extern cl::opt<bool> DisableGCSupport;
extern cl::opt<bool> EnableSafepointOnly;
extern cl::opt<bool> EnableSafepointOutline;
} // namespace llvm

namespace {
const static StringRef NewObjFastStr = "CJ_MCC_NewObjectFast";
const static StringRef NewObjFinalizerFastStr = "CJ_MCC_NewFinalizerFast";
constexpr StringRef SafepointStub = "CJ_Safepoint_Stub";
// Runtime P04 publishes every ZGC reservation (ZMaxVirtualReservations=100).
// This table is the P01 slot-domain ABI; query only the live entries.
constexpr unsigned kCjHeapRangeCap = 100;

// ZGC non-nmethod barriers use the current thread, never patched nmethod masks.
// These layout symbols are provided by the matching runtime ABI (#856).
static Value *loadBarrierABI(IRBuilder<> &B, Module *M, StringRef Symbol) {
  return B.CreateLoad(B.getInt64Ty(), M->getOrInsertGlobal(Symbol, B.getInt64Ty()),
                      Symbol.drop_front(2));
}

static Value *barrierField(IRBuilder<> &B, Module *M, Value *Base,
                           StringRef Offset, Type *FieldTy) {
  Value *Bytes = B.CreateBitCast(Base, B.getInt8PtrTy());
  Value *Address = B.CreateGEP(B.getInt8Ty(), Bytes, loadBarrierABI(B, M, Offset));
  return B.CreateBitCast(Address, FieldTy->getPointerTo());
}

static Value *loadThreadGCData(IRBuilder<> &B, Module *M) {
  const Triple TT(M->getTargetTriple());
  FunctionType *Ty = FunctionType::get(B.getInt8PtrTy(), false);
  const char *Asm = TT.isX86() ? "movq %r15, $0" : "mov $0, x28";
  Value *TLS = B.CreateCall(InlineAsm::get(Ty, Asm, "=r,~{memory}", true), {},
                            "cj.tls");
  return B.CreateLoad(B.getInt8PtrTy(),
      barrierField(B, M, TLS, "g_cjThreadGCDataOffset", B.getInt8PtrTy()),
      "cj.gcdata");
}

static Value *loadThreadMask(IRBuilder<> &B, Module *M, Value *Data,
                             StringRef Offset, StringRef Name) {
  return B.CreateLoad(B.getInt64Ty(),
                     barrierField(B, M, Data, Offset, B.getInt64Ty()), Name);
}

static unsigned storeStrength(const CallInst *CI) {
  if (CI->arg_size() == 4)
    if (const auto *S = dyn_cast<ConstantInt>(CI->getArgOperand(GCWriteRef::Strength)))
      return S->getZExtValue();
  return GCWriteRef::Unknown;
}

static Value *emitReservedHeapSlot(IRBuilder<> &Builder, Module *M, Value *PlaceI,
                                   const Twine &Name) {
  LLVMContext &C = M->getContext();
  Type *I64 = Type::getInt64Ty(C);
  ArrayType *ArrTy = ArrayType::get(I64, kCjHeapRangeCap);
  Value *Count = Builder.CreateLoad(
      I64, M->getOrInsertGlobal("g_cjHeapRangeCount", I64), Name + ".n");
  Constant *Starts = M->getOrInsertGlobal("g_cjHeapRangeStart", ArrTy);
  Constant *Ends = M->getOrInsertGlobal("g_cjHeapRangeEnd", ArrTy);

  // Keep the decision at this helper's original read/store call sites. The
  // runtime count controls a bounded loop, rather than unrolling empty slots.
  BasicBlock *Entry = Builder.GetInsertBlock();
  Instruction *ResumeAt = &*Builder.GetInsertPoint();
  Function *F = Entry->getParent();
  BasicBlock *Done = Entry->splitBasicBlock(ResumeAt, Name + ".done");
  BasicBlock *Check = BasicBlock::Create(C, Name + ".check", F, Done);
  BasicBlock *Loop = BasicBlock::Create(C, Name + ".loop", F, Done);
  BasicBlock *Next = BasicBlock::Create(C, Name + ".next", F, Done);
  BasicBlock *Invalid = BasicBlock::Create(C, Name + ".invalid", F, Done);
  Entry->getTerminator()->eraseFromParent();
  Builder.SetInsertPoint(Entry);
  Value *Valid = Builder.CreateICmpULE(Count, Builder.getInt64(kCjHeapRangeCap),
                                      Name + ".count.valid");
  Builder.CreateCondBr(Valid, Check, Invalid);

  Builder.SetInsertPoint(Invalid);
  Builder.CreateCall(Intrinsic::getDeclaration(M, Intrinsic::trap));
  Builder.CreateUnreachable();

  Builder.SetInsertPoint(Check);
  Builder.CreateCondBr(Builder.CreateICmpNE(Count, Builder.getInt64(0)), Loop, Done);

  Builder.SetInsertPoint(Loop);
  PHINode *Index = Builder.CreatePHI(I64, 2, Name + ".index");
  Index->addIncoming(Builder.getInt64(0), Check);
  Value *SPtr = Builder.CreateInBoundsGEP(
      ArrTy, Starts, {Builder.getInt64(0), Index}, Name + ".sp");
  Value *EPtr = Builder.CreateInBoundsGEP(
      ArrTy, Ends, {Builder.getInt64(0), Index}, Name + ".ep");
  Value *Start = Builder.CreateLoad(I64, SPtr, Name + ".start");
  Value *End = Builder.CreateLoad(I64, EPtr, Name + ".end");
  Value *Hit = Builder.CreateAnd(Builder.CreateICmpUGE(PlaceI, Start),
                                  Builder.CreateICmpULT(PlaceI, End), Name + ".hit");
  Builder.CreateCondBr(Hit, Done, Next);

  Builder.SetInsertPoint(Next);
  Value *NextIndex = Builder.CreateAdd(Index, Builder.getInt64(1), Name + ".next.index");
  Index->addIncoming(NextIndex, Next);
  Builder.CreateCondBr(Builder.CreateICmpULT(NextIndex, Count), Loop, Done);

  Builder.SetInsertPoint(ResumeAt);
  PHINode *In = Builder.CreatePHI(Builder.getInt1Ty(), 3, Name + ".result");
  In->addIncoming(Builder.getFalse(), Check);
  In->addIncoming(Builder.getTrue(), Loop);
  In->addIncoming(Builder.getFalse(), Next);
  return In;
}
template <typename KeyT, typename ValT>
using StdMap = std::unordered_map<KeyT, ValT>;
const static StdMap<unsigned, StringRef> IntrinsicMap{
    {Intrinsic::cj_gcwrite_ref, "CJ_MCC_WriteRefField"},
    {Intrinsic::cj_gcwrite_struct, "CJ_MCC_WriteStructField"},
    {Intrinsic::cj_gcwrite_static_ref, "CJ_MCC_WriteStaticRef"},
    {Intrinsic::cj_gcwrite_static_struct, "CJ_MCC_WriteStaticStruct"},
    {Intrinsic::cj_gcread_ref, "CJ_MCC_ReadRefField"},
    {Intrinsic::cj_gcread_weakref, "CJ_MCC_ReadWeakRef"},
    {Intrinsic::cj_gcread_struct, "CJ_MCC_ReadStructField"},
    {Intrinsic::cj_gcread_static_ref, "CJ_MCC_ReadStaticRef"},
    {Intrinsic::cj_gcread_static_struct, "CJ_MCC_ReadStaticStruct"},
    {Intrinsic::cj_copy_struct_field, "CJ_MCC_CopyStructField"},
    {Intrinsic::cj_array_copy_ref, "CJ_MCC_ArrayCopyRef"},
    {Intrinsic::cj_array_copy_struct, "CJ_MCC_ArrayCopyStruct"},
    {Intrinsic::cj_atomic_store, "CJ_MCC_AtomicWriteReference"},
    {Intrinsic::cj_atomic_load, "CJ_MCC_AtomicReadReference"},
    {Intrinsic::cj_atomic_swap, "CJ_MCC_AtomicSwapReference"},
    {Intrinsic::cj_atomic_compare_swap, "CJ_MCC_AtomicCompareAndSwapReference"},
    {Intrinsic::cj_assign_generic, "CJ_MCC_AssignGeneric"},
    {Intrinsic::cj_gcwrite_generic, "CJ_MCC_WriteGeneric"},
    {Intrinsic::cj_gcread_generic, "CJ_MCC_ReadGeneric"},
    {Intrinsic::cj_array_copy_generic, "CJ_MCC_ArrayCopyGeneric"},
    {Intrinsic::cj_gcwrite_generic_payload, "CJ_MCC_WriteGenericPayload"},
    {Intrinsic::cj_gcread_generic_payload, "CJ_MCC_ReadGenericPayload"}};

/// Declarations for Cangjie barrier functions.
class BarrierMaker {
public:
  BarrierMaker(Module &M, CJStructTypeGCInfo &GCInfo)
      : M(M), C(M.getContext()), GCInfo(GCInfo) {
    GCPtr = Type::getInt8PtrTy(C, 1);
    I8Ptr = Type::getInt8PtrTy(C);
    I64 = Type::getInt64Ty(C);
    I32 = Type::getInt32Ty(C);
  }

  ~BarrierMaker() = default;

  void replaceInstWithBarrier(IntrinsicInst *II) {
    if (II->isTailCall()) {
      II->setTailCall(false);
    }

    Function *Callee = getOrInsertRuntimeFunc(II);
    switch (II->getIntrinsicID()) {
    case Intrinsic::cj_gcwrite_ref:
      replaceCallInst(Callee, {II->getArgOperand(0), II->getArgOperand(1),
                               II->getArgOperand(2)}, II);
      break;
    case Intrinsic::cj_gcwrite_struct: {
      Value *GCTib = getOrInsertGCTib(II);
      Value *Param[6] = {II->getArgOperand(GCWriteStruct::BaseObj),
                         II->getArgOperand(GCWriteStruct::Dst),
                         II->getArgOperand(GCWriteStruct::Size),
                         II->getArgOperand(GCWriteStruct::Src),
                         II->getArgOperand(GCWriteStruct::Size), GCTib};
      // gcwrite.agg src has two case:
      // i8* on the stack and i8 addrspace(1)* on the heap.
      // The runtime function has only one signature. Here, the src of i8*
      // is converted to i8 addrspace(1)*.
      if (!isGCPointerType(II->getArgOperand(GCWriteStruct::Src)->getType())) {
        Param[3] = new AddrSpaceCastInst(II->getArgOperand(GCWriteStruct::Src),
                                         Type::getInt8PtrTy(C, 1), "", II);
      }
      // Replace the original intrinsic with the runtime function.
      replaceCallInst(Callee, Param, II);
      break;
    }
    case Intrinsic::cj_gcread_struct: {
      Value *GCTib = getOrInsertGCTib(II);
      Value *Param[5] = {II->getArgOperand(GCReadStruct::Dst),
                         II->getArgOperand(GCReadStruct::BaseObj),
                         II->getArgOperand(GCReadStruct::Src),
                         II->getArgOperand(GCReadStruct::Size), GCTib};
      // Replace the original intrinsic with the runtime function.
      replaceCallInst(Callee, Param, II);
      break;
    }
    case Intrinsic::cj_gcread_static_struct:
    case Intrinsic::cj_gcwrite_static_struct: {
      Value *GCTib = getOrInsertGCTib(II);
      Value *Param[5] = {II->getArgOperand(GCWriteStaticStruct::Dst),
                         II->getArgOperand(GCWriteStaticStruct::Size),
                         II->getArgOperand(GCWriteStaticStruct::Src),
                         II->getArgOperand(GCWriteStaticStruct::Size), GCTib};
      // Replace the original intrinsic with the runtime function.
      replaceCallInst(Callee, Param, II);
      break;
    }
    case Intrinsic::cj_array_copy_ref:
    case Intrinsic::cj_array_copy_struct:
    case Intrinsic::cj_array_copy_generic: {
      Value *Param[6] = {II->getArgOperand(ArrayCopy::DstObj),
                         II->getArgOperand(ArrayCopy::DstPtr),
                         II->getArgOperand(ArrayCopy::Size),
                         II->getArgOperand(ArrayCopy::SrcObj),
                         II->getArgOperand(ArrayCopy::SrcPtr),
                         II->getArgOperand(ArrayCopy::Size)};
      // Replace the original intrinsic with the runtime function.
      replaceCallInst(Callee, Param, II);
      break;
    }
    default:
      II->setCalledFunction(Callee);
      break;
    }
  }

  void replaceCallInst(Function *Callee, ArrayRef<Value *> Args,
                       IntrinsicInst *II) const {
    IRBuilder<> Builder(II);
    CallInst *NewCI = Builder.CreateCall(Callee, Args);
    II->replaceAllUsesWith(NewCI);
    II->eraseFromParent();
  }

private:
  Module &M;
  LLVMContext &C;
  CJStructTypeGCInfo &GCInfo;
  DenseMap<StringRef, Function *> RTFuncMap;
  Type *GCPtr;
  Type *I8Ptr;
  Type *I64;
  Type *I32;

  StringRef getRuntimeFuncName(IntrinsicInst *II) {
    Intrinsic::ID IID = II->getIntrinsicID();
    if (IID == Intrinsic::cj_gcwrite_ref) {
      if (storeStrength(II) == GCWriteRef::Strong) return "CJ_MCC_WriteRefField_Strong";
      if (storeStrength(II) == GCWriteRef::NoKeepAlive) return "CJ_MCC_WriteRefField_Weak";
    }
    auto Itr = IntrinsicMap.find(IID);
    assert(Itr != IntrinsicMap.end() && "Runtime Intrinsic don`t exist.");
    return Itr->second;
  }

  Function *getOrInsertRuntimeFunc(IntrinsicInst *II) {
    StringRef Callee = getRuntimeFuncName(II);
    assert(Callee != "" && "Callee don`t exist.");
    auto Itr = RTFuncMap.find(Callee);
    if (Itr != RTFuncMap.end())
      return Itr->second;
    // add dstLen to runtime API
    FunctionType *FuncType = nullptr;
    const Triple TT(II->getModule()->getTargetTriple());
    auto isARM = TT.isARM();
    switch (II->getIntrinsicID()) {
    case Intrinsic::cj_gcwrite_ref:
      FuncType = FunctionType::get(Type::getVoidTy(C),
          {II->getArgOperand(0)->getType(), II->getArgOperand(1)->getType(),
           II->getArgOperand(2)->getType()}, false);
      break;
    case Intrinsic::cj_gcwrite_struct: {
      Type *ParamType[6] = {GCPtr, GCPtr, I64, GCPtr, I64, I8Ptr};
      if (isARM)
        ParamType[2] = ParamType[4] = I32;
      FuncType = FunctionType::get(Type::getVoidTy(C), ParamType, false);
      break;
    }
    case Intrinsic::cj_gcread_struct: {
      Type *ParamType[5] = {I8Ptr, GCPtr, GCPtr, I64, I8Ptr};
      if (isARM)
        ParamType[3] = I32;
      FuncType = FunctionType::get(Type::getVoidTy(C), ParamType, false);
      break;
    }
    case Intrinsic::cj_gcread_static_struct:
    case Intrinsic::cj_gcwrite_static_struct: {
      Type *ParamType[5] = {I8Ptr, I64, I8Ptr, I64, I8Ptr};
      if (isARM)
        ParamType[1] = ParamType[3] = I32;
      FuncType = FunctionType::get(Type::getVoidTy(C), ParamType, false);
      break;
    }
    case Intrinsic::cj_array_copy_ref:
    case Intrinsic::cj_array_copy_struct:
    case Intrinsic::cj_array_copy_generic: {
      Type *ParamType[6] = {GCPtr, GCPtr, I64, GCPtr, GCPtr, I64};
      if (isARM)
        ParamType[2] = ParamType[5] = I32;
      FuncType = FunctionType::get(Type::getVoidTy(C), ParamType, false);
      break;
    }
    default:
      FuncType = II->getFunctionType();
      break;
    }
    Function *Func =
        cast<Function>(M.getOrInsertFunction(Callee, FuncType).getCallee());
    RTFuncMap.insert({Callee, Func});
    return Func;
  }

  Constant *getOrInsertGCTib(IntrinsicInst *II) const {
    const MDNode *Metadata = II->getMetadata("AggType");
    assert(Metadata && "Missing AggType Metadata.");
    assert(Metadata->getNumOperands() == 1 &&
           "AggType meta's size should be equal to 1!");

    auto STName =
        dyn_cast<MDString>(Metadata->getOperand(0).get())->getString();
    auto *ST = StructType::getTypeByName(C, STName);
    assert(ST && "AggType doesn't exsit.");

    Type *DstType = Type::getInt8PtrTy(C);
    std::string BitMapName = STName.str();
    Constant *BitMapGV = M.getGlobalVariable(BitMapName + ".bitmap");
    if (BitMapGV == nullptr) {
      auto &Info = GCInfo.getOrInsertTypeGCInfo(ST);
      BitMapGV =
          GCInfo.getOrInsertBitMap(Info.BMInfo.BMStr, DstType, BitMapName);
    } else {
      BitMapGV = ConstantExpr::getBitCast(BitMapGV, DstType);
    }
    assert(BitMapGV && "BitMapGV get or insert fail");
    return BitMapGV;
  }
};

// ZBarrierSet::barrier_needed (zBarrierSet.cpp:230-244): the storage
// contract, not the collection phase, determines whether a barrier is needed.
// Preserve P01's proof for plain stack/value storage. A null owner alone is
// not sufficient: an unknown AS1 slot must retain its runtime barrier.
static bool hasProvenNonHeapDestination(Value *Dst) {
  auto *DstTy = dyn_cast<PointerType>(Dst->getType());
  if (DstTy && DstTy->getAddressSpace() == 0)
    return true;

  Value *Base = findMemoryBasePointer(Dst);
  if (isa<AllocaInst>(Base))
    return true;
  auto *BaseTy = dyn_cast<PointerType>(Base->getType());
  return BaseTy && BaseTy->getAddressSpace() == 0;
}

static bool hasProvenNonHeapDestination(CallBase *CI) {
  Value *Dst = nullptr;
  switch (CI->getIntrinsicID()) {
  case Intrinsic::cj_gcwrite_ref:
    Dst = getPointerArg(CI);
    break;
  case Intrinsic::cj_gcwrite_struct:
    Dst = getDest(CI);
    break;
  default:
    return false;
  }

  return hasProvenNonHeapDestination(Dst);
}

// ZBarrierSetC2::set_barrier_data (zBarrierSetC2.cpp:341-364) determines
// the storage domain before emitting the barrier. Cangjie also has stack
// objects and headerless value storage in AS1: AS1 alone is not a proof.
// Inspect the final allocation statepoint, after partial escape analysis.
static bool hasHeapAllocationOrigin(Value *Ptr,
                                    SmallPtrSetImpl<Value *> &Active,
                                    DenseMap<Value *, bool> &Known) {
  auto It = Known.find(Ptr);
  if (It != Known.end())
    return It->second;
  if (!Ptr->getType()->isPointerTy() ||
      Ptr->getType()->getPointerAddressSpace() != 1 ||
      Active.size() == 64 || !Active.insert(Ptr).second)
    return false;

  bool Proven = [&]() {
    if (auto *Result = dyn_cast<GCResultInst>(Ptr)) {
      auto *SP = dyn_cast<GCStatepointInst>(Result->getStatepoint());
      const Function *Callee = SP ? SP->getActualCalledFunction() : nullptr;
      if (!Callee)
        return false;
      StringRef Name = Callee->getName();
      return Name.isCangjieNewObjFunction() || Name == NewObjFastStr ||
             Name == NewObjFinalizerFastStr || Name == "CJ_MCC_NewPinnedObject" ||
             Name == "CJ_MCC_NewArray" || Name == "CJ_MCC_NewArray8" ||
             Name == "CJ_MCC_NewArray16" || Name == "CJ_MCC_NewArray32" ||
             Name == "CJ_MCC_NewArray64" || Name == "CJ_MCC_NewObjArray";
    }
    if (auto *Relocate = dyn_cast<GCRelocateInst>(Ptr))
      return hasHeapAllocationOrigin(Relocate->getDerivedPtr(), Active, Known);
    if (auto *GEP = dyn_cast<GEPOperator>(Ptr))
      return GEP->isInBounds() &&
             hasHeapAllocationOrigin(GEP->getPointerOperand(), Active, Known);
    if (auto *Op = dyn_cast<Operator>(Ptr))
      if (Op->getOpcode() == Instruction::BitCast ||
          Op->getOpcode() == Instruction::AddrSpaceCast)
        return hasHeapAllocationOrigin(Op->getOperand(0), Active, Known);
    if (auto *Phi = dyn_cast<PHINode>(Ptr)) {
      for (Value *Incoming : Phi->incoming_values())
        if (!hasHeapAllocationOrigin(Incoming, Active, Known))
          return false;
      return Phi->getNumIncomingValues() != 0;
    }
    if (auto *Select = dyn_cast<SelectInst>(Ptr))
      return hasHeapAllocationOrigin(Select->getTrueValue(), Active, Known) &&
             hasHeapAllocationOrigin(Select->getFalseValue(), Active, Known);
    return false;
  }();
  Active.erase(Ptr);
  Known[Ptr] = Proven;
  return Proven;
}

static bool hasProvenHeapDestination(Value *Dst) {
  SmallPtrSet<Value *, 16> Active;
  DenseMap<Value *, bool> Known;
  bool Proven = hasHeapAllocationOrigin(Dst, Active, Known);
  if (Proven && hasProvenNonHeapDestination(Dst))
    report_fatal_error("conflicting heap and non-heap destination proofs");
  return Proven;
}

// ZGC barrierSetC2.cpp:973-999. Unknown (including dynamic) offsets must not
// become a new base with an apparently concrete zero displacement.
static Value *getAccessAddress(CallInst *Access) {
  switch (Access->getIntrinsicID()) {
  case Intrinsic::cj_atomic_load:
    return Access->getArgOperand(AtomicLoad::Field);
  case Intrinsic::cj_atomic_store:
    return Access->getArgOperand(AtomicStore::Field);
  case Intrinsic::cj_atomic_swap:
    return Access->getArgOperand(AtomicSwap::Field);
  case Intrinsic::cj_atomic_compare_swap:
    return Access->getArgOperand(AtomicCompareSwap::Field);
  default:
    return getPointerArg(Access);
  }
}

static Value *getBaseAndOffset(CallInst *Access, APInt &Offset) {
  Value *Base = getAccessAddress(Access);
  const DataLayout &DL = Access->getModule()->getDataLayout();
  Offset = APInt(DL.getIndexTypeSizeInBits(Base->getType()), 0);
  for (;;) {
    if (auto *GEP = dyn_cast<GEPOperator>(Base)) {
      if (!GEP->accumulateConstantOffset(DL, Offset))
        return nullptr;
      Base = GEP->getPointerOperand();
    } else if (auto *Cast = dyn_cast<BitCastOperator>(Base)) {
      Base = Cast->getOperand(0);
    } else {
      return Offset.isNegative() ? nullptr : Base;
    }
  }
}

// ZGC barrierSetC2.cpp:905-918: all statepoints, not just polling stubs.
static bool blockHasSafepoint(BasicBlock::iterator From,
                              BasicBlock::iterator To) {
  return llvm::any_of(make_range(From, To), [](Instruction &I) {
    return isa<GCStatepointInst>(&I);
  });
}

static bool blockHasSafepoint(BasicBlock *BB) {
  return blockHasSafepoint(BB->begin(), BB->end());
}

// ZGC zBarrierSetC2.cpp:476-478. Atomic writes/RMWs currently use the runtime
// Access API (A6), with no inline elided consumer. Never attach a dead proof.
static void elideDominatedBarrier(CallInst *Access) {
  switch (Access->getIntrinsicID()) {
  case Intrinsic::cj_gcread_ref:
  case Intrinsic::cj_gcwrite_ref:
    break;
  case Intrinsic::cj_atomic_load:
    if (isa<ConstantInt>(getAtomicOrder(Access)))
      break;
    return;
  default:
    return;
  }
  Access->setMetadata(BarrierElidedMD, MDNode::get(Access->getContext(), {}));
}

// ZGC barrierSetC2.cpp:1066-1159, access arm. Keep the same-block interval
// check and the deliberately whole-block predecessor walk as separate arms.
static void elideDominatedBarriers(ArrayRef<CallInst *> Accesses,
                                   ArrayRef<CallInst *> Dominators,
                                   DominatorTree &DT) {
  for (CallInst *Access : Accesses) {
    APInt AccessOffset;
    Value *AccessBase = getBaseAndOffset(Access, AccessOffset);
    if (!AccessBase)
      continue;
    BasicBlock *AccessBlock = Access->getParent();
    for (CallInst *Mem : Dominators) {
      APInt MemOffset;
      Value *MemBase = getBaseAndOffset(Mem, MemOffset);
      if (!MemBase || MemBase != AccessBase || MemOffset != AccessOffset)
        continue;
      BasicBlock *MemBlock = Mem->getParent();
      if (MemBlock == AccessBlock) {
        if (Mem != Access && Mem->comesBefore(Access) &&
            !blockHasSafepoint(std::next(Mem->getIterator()),
                              Access->getIterator()))
          elideDominatedBarrier(Access);
      } else if (DT.dominates(MemBlock, AccessBlock)) {
        SmallVector<BasicBlock *, 16> Stack{AccessBlock};
        SmallPtrSet<BasicBlock *, 16> Visited;
        bool SafepointFound = blockHasSafepoint(AccessBlock);
        while (!SafepointFound && !Stack.empty()) {
          BasicBlock *BB = Stack.pop_back_val();
          if (!Visited.insert(BB).second)
            continue;
          if (blockHasSafepoint(BB)) {
            SafepointFound = true;
            break;
          }
          if (BB == MemBlock)
            continue;
          llvm::append_range(Stack, predecessors(BB));
        }
        if (!SafepointFound)
          elideDominatedBarrier(Access);
      }
    }
  }
}

// ZGC zBarrierSetC2.cpp:480-552: first collect three access/dominator lists,
// then apply the common proof. B2 can add allocations to load/store dominators.
static void analyzeDominatingBarriers(Function &F) {
  SmallVector<CallInst *, 16> Loads, LoadDominators;
  SmallVector<CallInst *, 16> Stores, StoreDominators;
  SmallVector<CallInst *, 16> Atomics, AtomicDominators;
  for (Instruction &I : instructions(F)) {
    auto *CI = dyn_cast<CallInst>(&I);
    if (!CI)
      continue;
    switch (CI->getIntrinsicID()) {
    case Intrinsic::cj_gcread_ref:
    case Intrinsic::cj_atomic_load:
      if (hasProvenHeapDestination(getAccessAddress(CI))) {
        Loads.push_back(CI);
        LoadDominators.push_back(CI);
      }
      break;
    case Intrinsic::cj_gcwrite_ref:
    case Intrinsic::cj_atomic_store:
      if (hasProvenHeapDestination(getAccessAddress(CI))) {
        Stores.push_back(CI);
        LoadDominators.push_back(CI);
        StoreDominators.push_back(CI);
        AtomicDominators.push_back(CI);
      }
      break;
    case Intrinsic::cj_atomic_swap:
    case Intrinsic::cj_atomic_compare_swap:
      if (hasProvenHeapDestination(getAccessAddress(CI))) {
        Atomics.push_back(CI);
        LoadDominators.push_back(CI);
        StoreDominators.push_back(CI);
        AtomicDominators.push_back(CI);
      }
      break;
    default:
      break;
    }
  }
  DominatorTree DT(F);
  elideDominatedBarriers(Loads, LoadDominators, DT);
  elideDominatedBarriers(Stores, StoreDominators, DT);
  elideDominatedBarriers(Atomics, AtomicDominators, DT);
}

class ReadBarrier {
public:
  explicit ReadBarrier(Function &F) : M(F.getParent()), C(F.getContext()) {
    const Triple TT(M->getTargetTriple());
    IsX86_64 = TT.getArch() == Triple::x86_64;
  }

  ~ReadBarrier() = default;

  bool readFastPath(CallInst *ReadBarrier, Value *RefFieldPtr,
                    uint64_t Order = 0) {
    setBarrier(ReadBarrier);
    IRBuilder<> Builder(ReadInst);
    // z_x86_64.ad:61-82: an elided heap load still uncolors its loaded value.
    if (ReadInst->getMetadata(BarrierElidedMD)) {
      LoadInst *Load = loadTaggedPointer(Builder, RefFieldPtr, Order);
      Value *Bits = Builder.CreatePtrToInt(Load, Builder.getInt64Ty());
      Value *Uncolored = uncolor(Builder, Bits);
      ReadInst->replaceAllUsesWith(Uncolored);
      ReadInst->eraseFromParent();
      return true;
    }
    BasicBlock *Domain = nullptr;
    Value *InHeap = nullptr;
    if (ReadBarrier->getIntrinsicID() == Intrinsic::cj_gcread_ref &&
        !hasProvenHeapDestination(RefFieldPtr)) {
      // Value-type storage can be plain. Route it to the accessor before
      // entering the heap fast path, whose only predicate is the mask test.
      Value *PlaceI = Builder.CreatePtrToInt(RefFieldPtr, Builder.getInt64Ty(),
                                             "cj.read.place.i");
      InHeap = emitReservedHeapSlot(Builder, M, PlaceI, "cj.read.inheap");
      Domain = ReadInst->getParent();
      Domain->splitBasicBlock(ReadInst, "loadFast");
      Builder.SetInsertPoint(ReadInst);
    }
    LoadInst *Load = loadTaggedPointer(Builder, RefFieldPtr, Order);
    Instruction *PtrToInt =
        cast<Instruction>(Builder.CreatePtrToInt(Load, Type::getInt64Ty(C)));
    PtrToInt->setDebugLoc(*Loc);
    Value *CmpEQ = cmpTaggedPointer(PtrToInt, Builder);
    splitFastPathAndSlowPath(ReadInst->getParent(), CmpEQ, PtrToInt, Domain, InHeap);
    return false;
  }

  // insert a load from RefFieldPtr:
  //   %val = load i8 addrspace1*, i8 addrspace1* addrspace1* %RefFieldPtr
  LoadInst *loadTaggedPointer(IRBuilder<> &Builder, Value *RefFieldPtr,
                              uint64_t Order) {
    LoadInst *Load = Builder.CreateLoad(DstTy, RefFieldPtr);
    Load->setDebugLoc(*Loc);
    Load->setMetadata("cj.colored.value", MDNode::get(C, {}));
    if (Order) {
      Load->setAtomic(
          (AtomicOrdering)(Order + (uint64_t)AtomicOrdering::Monotonic));
    }
    return Load;
  }

  // ZGC x86 load_at: test the current thread load-bad mask.
  Value *cmpTaggedPointer(Value *TagPtr, IRBuilder<> &Builder) {
    Type *I64 = Type::getInt64Ty(C);
    Value *Mask = loadThreadMask(Builder, M, loadThreadGCData(Builder, M),
                                "g_cjLoadBadMaskOffset", "cj.loadbadmask");
    cast<Instruction>(Mask)->setDebugLoc(*Loc);
    Value *Bad = Builder.CreateAnd(TagPtr, Mask);
    cast<Instruction>(Bad)->setDebugLoc(*Loc);
    Value *CmpEQ = Builder.CreateICmpEQ(Bad, ConstantInt::get(I64, (uint64_t)0));
    cast<Instruction>(CmpEQ)->setDebugLoc(*Loc);
    return CmpEQ;
  }

  // preBB:
  //   %Cond = icmp eq i64 %tag, 0
  //   br i1 %Cond, label %gcNoMarked label %gcMarked
  // gcNoMarked:
  //   %address = lshr i64 %PtrToInt, @g_cjLoadShift
  //   %val1 = inttoptr i64 %address to i8 addrspace(1)*
  //   br label %loadFinish
  // gcMarked:
  //   %val2 = call @llvm.cj.gcread.ref
  //   br label %loadFinish
  // loadFinish:
  //   %val = phi [%val1, gcNoMarked], [%val2, gcMarked]
  void splitFastPathAndSlowPath(BasicBlock *SplitBB, Value *Condition,
                                Instruction *PtrToInt, BasicBlock *Domain,
                                Value *InHeap) {
    BasicBlock *FalseBranch = SplitBB->splitBasicBlock(ReadInst, "gcMarked");
    if (Domain) {
      Instruction *OldBranch = Domain->getTerminator();
      IRBuilder<> DomainBuilder(OldBranch);
      DomainBuilder.CreateCondBr(InHeap, SplitBB, FalseBranch);
      OldBranch->eraseFromParent();
    }
    BasicBlock *Succ =
        FalseBranch->splitBasicBlock(ReadInst->getNextNode(), "loadFinish");
    BasicBlock *TrueBranch =
        BasicBlock::Create(C, "gcNoMarked", SplitBB->getParent(), Succ);
    BranchInst::Create(Succ, TrueBranch);
    IRBuilder<> Builder(TrueBranch->getTerminator());
    Value *Uncolored = uncolor(Builder, PtrToInt);
    Instruction *OriginBr = SplitBB->getTerminator();
    IRBuilder<> BuilderBr(OriginBr);
    BuilderBr.CreateCondBr(Condition, TrueBranch, FalseBranch);
    OriginBr->eraseFromParent();
    TrueBranch->getTerminator()->setDebugLoc(*Loc);
    FalseBranch->getTerminator()->setDebugLoc(*Loc);
    handleSuccPhi(FalseBranch, Uncolored, TrueBranch, Succ);
    return;
  }

  Value *uncolor(IRBuilder<> &Builder, Value *PtrToInt) {
    // ZPointer::uncolor, zAddress.inline.hpp:609-614. The fast path has
    // established the current remap epoch, so use its published load shift.
    Type *I64 = Type::getInt64Ty(C);
    Constant *ShiftGV = M->getOrInsertGlobal("g_cjLoadShift", I64);
    Value *Shift = Builder.CreateLoad(I64, ShiftGV, "cj.load.shift");
    Value *Address = Builder.CreateLShr(PtrToInt, Shift, "cj.load.address");
    cast<Instruction>(Address)->setDebugLoc(*Loc);
    Instruction *Uncolored =
        cast<Instruction>(Builder.CreateIntToPtr(Address, DstTy));
    Uncolored->setDebugLoc(*Loc);
    return Uncolored;
  }

  PHINode *handleSuccPhi(BasicBlock *FalseBranch, Value *FastInst,
                         BasicBlock *TrueBranch, BasicBlock *Succ) {
    IRBuilder<> Builder(Succ->getFirstNonPHI());
    PHINode *Phi = Builder.CreatePHI(DstTy, 2);
    ReadInst->replaceAllUsesWith(Phi);
    Phi->addIncoming(ReadInst, FalseBranch);
    Phi->addIncoming(FastInst, TrueBranch);
    return Phi;
  }

  void setBarrier(CallInst *CI) {
    ReadInst = CI;
    DstTy = CI->getType();
    Loc = &CI->getDebugLoc();
  }

private:
  Module *M;
  LLVMContext &C;
  bool IsX86_64;
  CallInst *ReadInst = nullptr;
  Type *DstTy = nullptr;
  const DebugLoc *Loc = nullptr;
};

// ZGC zBarrierSetAssembler_x86.cpp:428-628, non-nmethod store barriers.
class WriteBarrier {
public:
  explicit WriteBarrier(Function &F) : M(F.getParent()), C(F.getContext()) {}

  bool storeFastPath(CallInst *CI) {
    IRBuilder<> B(CI);
    B.SetCurrentDebugLocation(CI->getDebugLoc());
    Value *Place = getPointerArg(CI);
    Value *NewVal = getValueArg(CI);
    Type *I64 = B.getInt64Ty();
    // z_x86_64.ad:84-99: route before constructing checks or registering stubs.
    if (CI->getMetadata(BarrierElidedMD)) {
      Value *Colored;
      if (isa<ConstantPointerNull>(NewVal)) {
        // zStorePNull, z_x86_64.ad:180-185, stores a colored null directly.
        Colored = loadThreadMask(B, M, loadThreadGCData(B, M),
                                 "g_cjStoreGoodMaskOffset", "cj.storegoodmask");
      } else {
        Colored = color(B, NewVal);
      }
      Value *WordPtr = B.CreateBitCast(Place,
          PointerType::get(I64, Place->getType()->getPointerAddressSpace()));
      B.CreateStore(Colored, WordPtr, true);
      CI->eraseFromParent();
      return true;
    }
    Function *F = CI->getFunction();
    BasicBlock *Entry = CI->getParent();
    BasicBlock *Done = Entry->splitBasicBlock(CI, "storeDone");
    BasicBlock *Native = BasicBlock::Create(C, "storeAccessor", F, Done);
    BasicBlock *Fast = BasicBlock::Create(C, "storeFast", F, Done);
    BasicBlock *Medium = BasicBlock::Create(C, "storeMedium", F, Done);
    BasicBlock *Slow = BasicBlock::Create(C, "storeSlow", F, Done);
    BasicBlock *Store = BasicBlock::Create(C, "storeFinish", F, Done);
    Entry->getTerminator()->eraseFromParent();
    B.SetInsertPoint(Entry);
    // Cangjie value types may name stack/plain storage. Classify the slot
    // before entering the heap barrier, as the runtime accessor does.
    B.CreateBr(Done);
    B.SetInsertPoint(Entry->getTerminator());
    Value *InHeap = hasProvenHeapDestination(Place)
        ? B.getTrue()
        : emitReservedHeapSlot(B, M, B.CreatePtrToInt(Place, I64),
                               "cj.store.inheap");
    Instruction *OldBranch = B.GetInsertBlock()->getTerminator();
    B.CreateCondBr(InHeap, Fast, Native);
    OldBranch->eraseFromParent();
    B.SetInsertPoint(Native);
    B.CreateBr(Done);
    CI->moveBefore(Native->getTerminator());

    B.SetInsertPoint(Fast);
    Value *Data = nullptr;
    Value *WordPtr = nullptr;
    Value *Colored = storeBarrierFast(B, Place, NewVal, Medium, Store, Data, WordPtr);
    B.CreateStore(Colored, WordPtr, true);
    B.CreateBr(Done);

    B.SetInsertPoint(Medium);
    storeBarrierMedium(B, storeStrength(CI), Data, WordPtr, Slow, Store);

    B.SetInsertPoint(Slow);
    StringRef Name = storeStrength(CI) == GCWriteRef::NoKeepAlive
        ? "CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive"
        : "CJ_MCC_StoreBarrierOnHeapField";
    FunctionType *SlowTy = FunctionType::get(B.getVoidTy(), {Place->getType()}, false);
    B.CreateCall(M->getOrInsertFunction(Name, SlowTy), {Place});
    B.CreateBr(Store);
    return false;
  }

private:
  Value *storeBarrierFast(IRBuilder<> &B, Value *Place, Value *NewVal,
                           BasicBlock *Medium, BasicBlock *Store,
                           Value *&Data, Value *&WordPtr) {
    Type *I64 = B.getInt64Ty();
    Data = loadThreadGCData(B, M);
    WordPtr = B.CreateBitCast(Place,
        PointerType::get(I64, Place->getType()->getPointerAddressSpace()));
    Value *LowPtr = B.CreateBitCast(Place,
        PointerType::get(B.getInt16Ty(), Place->getType()->getPointerAddressSpace()));
    Value *Prev = B.CreateZExt(B.CreateLoad(B.getInt16Ty(), LowPtr), I64,
                              "cj.store.prev.low");
    Value *Mask = loadThreadMask(B, M, Data, "g_cjStoreBadMaskOffset", "cj.storebadmask");
    Value *Bad = B.CreateAnd(Prev, Mask, "cj.store.bad");
    B.CreateCondBr(B.CreateICmpEQ(Bad, B.getInt64(0)), Store, Medium);

    B.SetInsertPoint(Store);
    return color(B, NewVal);
  }

  Value *color(IRBuilder<> &B, Value *NewVal) {
    Type *I64 = B.getInt64Ty();
    FunctionType *CopyTy = FunctionType::get(I64, {NewVal->getType()}, false);
    const Triple TT(M->getTargetTriple());
    InlineAsm *Copy = InlineAsm::get(CopyTy,
        TT.isX86() ? "movq $1, $0" : "mov $0, $1", "=&r,r", false);
    Value *NewBits = B.CreateCall(Copy, NewVal, "cj.store.new.bits");
    Value *Shift = B.CreateLoad(I64, M->getOrInsertGlobal("g_cjLoadShift", I64), "cj.store.shift");
    Value *Good = loadThreadMask(B, M, loadThreadGCData(B, M),
                                "g_cjStoreGoodMaskOffset", "cj.storegoodmask");
    Value *Colored = B.CreateOr(B.CreateShl(NewBits, Shift), Good, "cj.store.colored");
    return Colored;
  }

  void storeBarrierMedium(IRBuilder<> &B, unsigned Strength, Value *Data,
                           Value *WordPtr, BasicBlock *Slow, BasicBlock *Store) {
    if (Strength == GCWriteRef::NoKeepAlive) {
      B.CreateBr(Slow);
      return;
    }
    storeBarrierBufferAdd(B, Data, WordPtr, Slow, Store);
  }

  void storeBarrierBufferAdd(IRBuilder<> &B, Value *Data, Value *Place,
                             BasicBlock *Slow, BasicBlock *Store) {
    Value *Buffer = B.CreateLoad(B.getInt8PtrTy(),
        barrierField(B, M, Data, "g_cjStoreBarrierBufferOffset", B.getInt8PtrTy()),
        "cj.store.buffer");
    Value *CurrentPtr = barrierField(B, M, Buffer,
        "g_cjStoreBarrierBufferCurrentOffset", B.getInt64Ty());
    Value *Current = B.CreateLoad(B.getInt64Ty(), CurrentPtr, "cj.store.current");
    BasicBlock *Append = BasicBlock::Create(C, "storeAppend", Slow->getParent(), Slow);
    B.CreateCondBr(B.CreateICmpEQ(Current, B.getInt64(0)), Slow, Append);
    B.SetInsertPoint(Append);
    Value *Next = B.CreateSub(Current,
        loadBarrierABI(B, M, "g_cjStoreBarrierEntrySize"), "cj.store.next");
    B.CreateStore(Next, CurrentPtr);
    Value *Entries = barrierField(B, M, Buffer,
        "g_cjStoreBarrierBufferBufferOffset", B.getInt8Ty());
    Value *Entry = B.CreateGEP(B.getInt8Ty(), Entries, Next, "cj.store.entry");
    B.CreateStore(B.CreatePtrToInt(Place, B.getInt64Ty()),
        barrierField(B, M, Entry, "g_cjStoreBarrierEntryPOffset", B.getInt64Ty()));
    Value *Prev = B.CreateLoad(B.getInt64Ty(), Place, "cj.store.buffer.prev");
    B.CreateStore(Prev,
        barrierField(B, M, Entry, "g_cjStoreBarrierEntryPrevOffset", B.getInt64Ty()));
    B.CreateBr(Store);
  }

  Module *M;
  LLVMContext &C;
};

/// CJBarrierLowering - This pass rewrites calls to the llvm.gcread or
/// llvm.gcwrite intrinsics, replacing them with simple loads and stores as
/// directed by the GCStrategy. It also performs automatic root initialization
/// and custom intrinsic lowering.
class CJBarrierLowering : public FunctionPass {
  bool isCJBarrier(Instruction *I);
  Instruction *createReadFastPath(BasicBlock *TrueBranch, Instruction *PtrToInt,
                                  const DebugLoc &Loc);
  PHINode *handleSuccPhi(Instruction *SlowInst, BasicBlock *FalseBranch,
                         Instruction *FastInst, BasicBlock *TrueBranch,
                         BasicBlock *Succ);
  void splitFastPathAndSlowPath(CallBase *ReadInst, BasicBlock *SplitBB,
                                Value *Condition, Instruction *PtrToInt,
                                const DebugLoc &Loc);
  void writeBarrierFastPath(Function &F, SetVector<CallInst *> &Barriers);
  void readBarrierFastPath(Function &F, SetVector<CallInst *> &Barriers);
  void doLowering(Function &F);

public:
  static char ID;
  CodeGenOpt::Level OptLevel;

  CJBarrierLowering(CodeGenOpt::Level OptLevel = CodeGenOpt::Default);
  StringRef getPassName() const override;
  void getAnalysisUsage(AnalysisUsage &AU) const override;

  bool runOnFunction(Function &F) override;
};
} // namespace

// -----------------------------------------------------------------------------

INITIALIZE_PASS_BEGIN(CJBarrierLowering, "cj-barrier-lowering",
                      "Cangjie Barrier Lowering", false, false)
INITIALIZE_PASS_END(CJBarrierLowering, "cj-barrier-lowering",
                    "Cangjie Barrier Lowering", false, false)

char CJBarrierLowering::ID = 0;
char &llvm::CJBarrierLoweringID = CJBarrierLowering::ID;

FunctionPass *llvm::createCJBarrierLoweringPass(CodeGenOpt::Level OptLevel) {
  return new CJBarrierLowering(OptLevel);
}

CJBarrierLowering::CJBarrierLowering(CodeGenOpt::Level OptLevel)
    : FunctionPass(ID), OptLevel(OptLevel) {
  initializeCJBarrierLoweringPass(*PassRegistry::getPassRegistry());
}

StringRef CJBarrierLowering::getPassName() const {
  return "Cangjie Lower Garbage Collection Barrier Function";
}

void CJBarrierLowering::getAnalysisUsage(AnalysisUsage &AU) const {
  FunctionPass::getAnalysisUsage(AU);
}

void CJBarrierLowering::writeBarrierFastPath(Function &F,
                                             SetVector<CallInst *> &Barriers) {
  if (EnableTaggedPointer && !CangjieJIT) {
    WriteBarrier WB(F);
    SmallVector<CallInst *, 8> Elided;
    for (CallInst *CI : Barriers) {
      if (!CI->getParent())
        continue;
      if (CI->getIntrinsicID() != Intrinsic::cj_gcwrite_ref)
        continue;
      // Without an elision proof, unknown accesses use the runtime accessor.
      if (storeStrength(CI) == GCWriteRef::Unknown &&
          !CI->getMetadata(BarrierElidedMD))
        continue;
      if (WB.storeFastPath(CI))
        Elided.push_back(CI);
    }
    for (CallInst *CI : Elided)
      Barriers.remove(CI);
  }

  if (CangjieJIT)
    return;

  // Discharge only statically proven plain-storage accesses here. Native
  // static roots and unknown heap slots always retain their color protocol.
  for (CallInst *CI : Barriers) {
    const unsigned IID = CI->getIntrinsicID();
    const bool RefOrStruct = IID == Intrinsic::cj_gcwrite_ref ||
                             IID == Intrinsic::cj_gcwrite_struct;
    const bool StaticRefOrStruct = IID == Intrinsic::cj_gcwrite_static_ref ||
                                   IID == Intrinsic::cj_gcwrite_static_struct;
    if (!RefOrStruct && !StaticRefOrStruct)
      continue;
    if (DisableGCSupport || EnableSafepointOnly ||
        (RefOrStruct && isa<ConstantPointerNull>(getBaseObj(CI)) &&
         hasProvenNonHeapDestination(CI))) {
      IRBuilder<> Builder(CI);
      createStoreOrMems(CI, Builder);
      CI->eraseFromParent();
    }
  }
}

// do the following conversion:
//   %val = call void @llvm.cj.gcread.ref
// =====>
//   %0 = load i8 addrspace1*, i8 addrspace1* addrspace1* %RefFieldPtr
//   %1 = ptrtoint i8 addrspace1* %0 to i64
//   %2 = and i64 %1, @g_cjLoadBadMask   (phase B; was `lshr i64 %1, 48`)
//   %3 = icmp eq i64 %2, 0
//   br i1 %3, label %gcNoMarked label %gcMarked
// gcNoMarked:
//   %val1 = lshr %0, @g_cjLoadShift
//   br label %loadFinish
// gcMarked:
//   %val2 = call @llvm.cj.gcread.ref
//   br label %loadFinish
// loadFinish:
//   %val = phi [%val1, gcNoMarked], [%val2, gcMarked]
void CJBarrierLowering::readBarrierFastPath(Function &F,
                                            SetVector<CallInst *> &Barriers) {
  if (!EnableTaggedPointer || CangjieJIT)
    return;

  ReadBarrier RB(F);
  SmallVector<CallInst *, 8> Elided;
  for (CallInst *CI : Barriers) {
    if (!CI->getParent())
      continue;
    unsigned ID = CI->getIntrinsicID();
    if (ID == Intrinsic::cj_gcread_ref ||
        ID == Intrinsic::cj_gcread_static_ref) {
      if (RB.readFastPath(CI, getPointerArg(CI)))
        Elided.push_back(CI);
      continue;
    }
    if (ID == Intrinsic::cj_atomic_load) {
      if (auto AO = dyn_cast<ConstantInt>(getAtomicOrder(CI))) {
        if (RB.readFastPath(CI, CI->getArgOperand(AtomicLoad::Field),
                            AO->getZExtValue()))
          Elided.push_back(CI);
      }
    }
  }
  for (CallInst *CI : Elided)
    Barriers.remove(CI);
}

void CJBarrierLowering::doLowering(Function &F) {
  Module *M = F.getParent();
  CJStructTypeGCInfo GCInfo(*M);
  BarrierMaker GCBarrier(*M, GCInfo);

  for (BasicBlock &BB : F) {
    for (Instruction &I : llvm::make_early_inc_range(BB)) {
      if (isCJBarrier(&I))
        GCBarrier.replaceInstWithBarrier(cast<IntrinsicInst>(&I));
    }
  }
}

bool CJBarrierLowering::isCJBarrier(Instruction *I) {
  IntrinsicInst *CI = dyn_cast<IntrinsicInst>(I);
  if (!CI)
    return false;

  switch (CI->getIntrinsicID()) {
  default:
    return false;
  case Intrinsic::cj_gcwrite_ref:
  case Intrinsic::cj_gcwrite_struct:
  case Intrinsic::cj_gcwrite_static_ref:
  case Intrinsic::cj_gcwrite_static_struct:
  case Intrinsic::cj_gcread_ref:
  case Intrinsic::cj_gcread_weakref:
  case Intrinsic::cj_gcread_struct:
  case Intrinsic::cj_gcread_static_ref:
  case Intrinsic::cj_gcread_static_struct:
  case Intrinsic::cj_copy_struct_field:
  case Intrinsic::cj_atomic_store:
  case Intrinsic::cj_atomic_load:
  case Intrinsic::cj_atomic_swap:
  case Intrinsic::cj_atomic_compare_swap:
  case Intrinsic::cj_array_copy_ref:
  case Intrinsic::cj_array_copy_struct:
  case Intrinsic::cj_array_copy_generic:
  case Intrinsic::cj_assign_generic:
  case Intrinsic::cj_gcwrite_generic:
  case Intrinsic::cj_gcread_generic:
  case Intrinsic::cj_gcwrite_generic_payload:
  case Intrinsic::cj_gcread_generic_payload:
    return true;
  }
}

static void replaceFastFunc(Function &F, GCStatepointInst *CI,
                            StringRef FuncName) {
  Module *M = F.getParent();
  Function *Func = M->getFunction(FuncName);
  if (Func == nullptr) {
    Function *Callee = CI->getActualCalledFunction();
    Func = M->declareCJRuntimeFunc(FuncName, Callee->getFunctionType(), true);
    Func->setLinkage(GlobalValue::InternalLinkage);
    Func->addFnAttr(Attribute::NoInline);
    Func->addFnAttr("cj-fast-new-obj");
    BasicBlock *BB = BasicBlock::Create(M->getContext(), "entry", Func);
    IRBuilder<> IRB(BB);
    auto Ret = IRB.CreateCall(Callee, {Func->getArg(0), Func->getArg(1)});
    IRB.CreateRet(Ret);
  }
  CI->setArgOperand(GCStatepointInst::CalledFunctionPos, Func);
}

static bool doNewFastPath(Function &F, SetVector<GCStatepointInst *> &NewObjs) {
  if (CangjieJIT)
    return false;
  for (GCStatepointInst *CI : NewObjs) {
    Function *Callee = CI->getActualCalledFunction();
    if (Callee->getName().equals("CJ_MCC_NewObject")) {
      replaceFastFunc(F, CI, NewObjFastStr);
    } else {
      replaceFastFunc(F, CI, NewObjFinalizerFastStr);
    }
  }
  return true;
}

static bool isNewObj(Instruction *I) {
  if (auto CI = dyn_cast<GCStatepointInst>(I)) {
    Function *Callee = CI->getActualCalledFunction();
    if (Callee && Callee->getName().isCangjieNewObjFunction()) {
      return true;
    }
  }
  return false;
}

static bool isSafepointCall(Instruction *I) {
  if (auto *CI = dyn_cast<GCStatepointInst>(I)) {
    Function *Callee = CI->getActualCalledFunction();
    if (Callee && Callee->isCangjieSafePoint())
      return true;
  }
  return false;
}

static Function *getOrInsertSafepointStub(Module *M, Function *Callee) {
  if (Function *F = M->getFunction(SafepointStub))
    return F;
  FunctionType *FuncType =
      FunctionType::get(Type::getVoidTy(M->getContext()), false);
  Function *F = cast<Function>(
      M->getOrInsertFunction(SafepointStub, FuncType).getCallee());
  F->addFnAttr(Attribute::NoInline);
  F->addFnAttr(Attribute::Naked);
  F->setLinkage(GlobalValue::PrivateLinkage);
  // Create function body.
  BasicBlock *BB = BasicBlock::Create(M->getContext(), "", F);
  IRBuilder<> IRB(BB);
  IRB.CreateCall(Callee);
  // Ret does not need to be generated, but the verification fails.
  IRB.CreateRetVoid();
  return F;
}

static bool combineSafepointStub(Module *M,
                                 SetVector<GCStatepointInst *> &Safepoints) {
  if (Safepoints.empty())
    return false;
  Function *F = getOrInsertSafepointStub(
      M, Safepoints.front()->getActualCalledFunction());
  for (auto *SI : Safepoints) {
    // Although the callee is replaced, the call is still a safepoint.
    SI->setArgOperand(GCStatepointInst::CalledFunctionPos, F);
    SI->setArgOperand(GCStatepointInst::IDPos,
                      ConstantInt::get(Type::getInt64Ty(M->getContext()),
                                       Cangjie::CJStatepointID::SafepointStub));
  }
  return true;
}

// llvm.cj.copy.no.ref.struct has already had its concrete AggType and exact
// size checked by CJIRVerifier.  It carries no reference slots and therefore
// bypasses CJBarrierSplit and all runtime barrier entry points.  Restore the
// original byte-copy operation immediately before ordinary CodeGen.
static bool lowerNoReferenceStructCopies(Function &F) {
  SmallVector<IntrinsicInst *, 4> Copies;
  for (BasicBlock &BB : F)
    for (Instruction &I : BB)
      if (auto *II = dyn_cast<IntrinsicInst>(&I))
        if (II->getIntrinsicID() == Intrinsic::cj_copy_no_ref_struct)
          Copies.push_back(II);

  for (IntrinsicInst *II : Copies) {
    IRBuilder<> Builder(II);
    CallInst *Copy = Builder.CreateMemCpy(
        II->getArgOperand(0), II->getParamAlign(0), II->getArgOperand(1),
        II->getParamAlign(1), II->getArgOperand(2), /*isVolatile=*/false);
    Copy->copyMetadata(*II);
    Copy->setMetadata(LLVMContext::MD_cj_agg, nullptr);
    Copy->setDebugLoc(II->getDebugLoc());
    II->eraseFromParent();
  }
  return !Copies.empty();
}

bool CJBarrierLowering::runOnFunction(Function &F) {
  bool Changed = lowerNoReferenceStructCopies(F);
  // Quick exit for functions that do not use Cangjie GC.
  if (!F.hasCangjieGC())
    return Changed;

  const Triple TT(F.getParent()->getTargetTriple());
  if (TT.isARM()){
    EnableTaggedPointer = false;
    EnableGCFastPath = false;
  }

  SetVector<CallInst *> Barriers;
  SetVector<GCStatepointInst *> News;
  SetVector<GCStatepointInst *> Safepoints;

  for (BasicBlock &BB : F) {
    for (Instruction &I : llvm::make_early_inc_range(BB)) {
      if (isCJBarrier(&I))
        Barriers.insert(cast<CallInst>(&I));
      else if (EnableGCFastPath && isNewObj(&I))
        News.insert(cast<GCStatepointInst>(&I));
      else if (EnableSafepointOutline && isSafepointCall(&I))
        Safepoints.insert(cast<GCStatepointInst>(&I));
    }
  }

  // Analyze the final statepoints before allocation expansion changes the CFG.
  if (EnableTaggedPointer && !CangjieJIT)
    analyzeDominatingBarriers(F);

  if (!News.empty()) {
    Changed = doNewFastPath(F, News);
  }

  if (!Safepoints.empty() && !TT.isARM())
    Changed |= combineSafepointStub(F.getParent(), Safepoints);

  // Independent of barrier set: bare CreateMemMove has no CJ barrier intrinsic.
  // Independent of barrier set: value-struct field load/store is a raw
  // LoadInst/StoreInst, not llvm.cj.gcread/gcwrite.

  if (Barriers.empty()) {
    return Changed;
  }

  // Store-good paint needs the load peel at every opt level, -O0 included
  // (zAddress.inline.hpp:609).
  readBarrierFastPath(F, Barriers);
  writeBarrierFastPath(F, Barriers);
  doLowering(F);
  return true;
}
