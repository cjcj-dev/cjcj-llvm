//===- CJWasmRoots.cpp - WASI shadow root frames, last Cangjie IR pass ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// wasm32-wasi managed ABI, compiler half (runtime half: CjWasmHeap.h).
//
// The collector is non-moving, single-threaded and stop-the-world. Wasm code
// cannot inspect its own value stack, so instead of ZGC's per-PC OopMaps
// (frame.cpp:995 -> oopMap.cpp:435/450) every function that needs one keeps a
// shadow frame in linear memory and publishes into it, before each call that
// may collect, the managed values it still needs afterwards. Published values
// are never reloaded: the collector does not move objects, so the original SSA
// values stay valid and no base/derived pairing is needed.
//
// I-FRAME: at any time __cj_root_top chains exactly the active Cangjie
//   activations that need a frame; nslots was written just before the current
//   may-collect call of each of them.
// I-LIVE: during a may-collect call every managed object the caller still uses
//   is addressed by one of its slots, lies in one of its ranges, or is
//   reachable from those objects through the heap.
// I-CARG: managed arguments are kept alive by the caller until the call
//   returns, so callees (Cangjie or runtime C) need not root parameters.
// I-RET: collection only happens inside allocation, so a returned reference
//   is safe until the caller's next slot store.
// I-INB: AS1 values point into [base, base + size] of their object. Rule 4
//   publishes the root of GEP/cast chains. A PHI/select with a non-inbounds or
//   inttoptr leaf also publishes that leaf's base when the base is an object
//   start dominating the site; any other unpublished base is rejected.
// I-BACKEND: this is the last IR pass; only llc follows, and the calls it
//   introduces are libc/compiler-rt leaves that do not allocate managed memory.
//
// Unsupported shapes are compile errors: musttail, callbr, inline asm,
// returns_twice, operand bundles, dynamic allocas that may hold references,
// managed vectors live across a call and oversized ranges.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/CJWasmRoots.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Triple.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/Transforms/Utils/ModuleUtils.h"

using namespace llvm;

namespace {
constexpr uint64_t MaxRangeBytes = 1u << 26;
constexpr StringLiteral DoneAttr = "cj-wasm-roots";

bool managed(Type *T) {
  auto *PT = dyn_cast<PointerType>(T);
  return PT && PT->getAddressSpace() == 1;
}

bool vectorOfManaged(Type *T) {
  if (auto *VT = dyn_cast<VectorType>(T))
    return managed(VT->getElementType());
  return false;
}

// Index paths of the AS1 leaves of a first-class aggregate. False when the
// aggregate holds managed vectors, which this ABI does not publish.
bool managedLeaves(Type *T, SmallVectorImpl<unsigned> &Path,
                   SmallVectorImpl<SmallVector<unsigned, 4>> &Out) {
  if (managed(T)) {
    Out.emplace_back(Path.begin(), Path.end());
    return true;
  }
  if (vectorOfManaged(T))
    return false;
  if (auto *ST = dyn_cast<StructType>(T)) {
    for (unsigned I = 0, E = ST->getNumElements(); I != E; ++I) {
      Path.push_back(I);
      bool OK = managedLeaves(ST->getElementType(I), Path, Out);
      Path.pop_back();
      if (!OK)
        return false;
    }
  } else if (auto *AT = dyn_cast<ArrayType>(T)) {
    for (uint64_t I = 0, E = AT->getNumElements(); I != E; ++I) {
      Path.push_back(unsigned(I));
      bool OK = managedLeaves(AT->getElementType(), Path, Out);
      Path.pop_back();
      if (!OK)
        return false;
    }
  }
  return true;
}

bool holdsManaged(Type *T) {
  if (managed(T) || vectorOfManaged(T))
    return true;
  if (auto *ST = dyn_cast<StructType>(T))
    return llvm::any_of(ST->elements(), holdsManaged);
  if (auto *AT = dyn_cast<ArrayType>(T))
    return holdsManaged(AT->getElementType());
  if (auto *VT = dyn_cast<VectorType>(T))
    return holdsManaged(VT->getElementType());
  return false;
}

// Rules 2 and 4 of the publication set: a GEP, bitcast, addrspacecast or
// ptrtoint chain stands for the value it starts from. Its uses keep that value
// live (a reference crossing a call only as an integer or an AS0 pointer is
// still published), and the chain root, not the derived address, is stored.
Value *rootOf(Value *V) {
  for (unsigned Depth = 0; Depth < 64; ++Depth) {
    if (auto *GEP = dyn_cast<GEPOperator>(V)) {
      V = GEP->getPointerOperand();
      continue;
    }
    if (isa<BitCastOperator>(V) || isa<AddrSpaceCastOperator>(V) ||
        isa<PtrToIntOperator>(V)) {
      V = cast<Operator>(V)->getOperand(0);
      continue;
    }
    break;
  }
  return V;
}

bool trackedRoot(const Value *V) {
  return (isa<Argument>(V) || isa<Instruction>(V)) && holdsManaged(V->getType());
}

// Rule 5: only a slot read and written as one integer/float of its own type,
// never holding a value derived from a reference, cannot hold a reference.
// Every other alloca is a range, scanned byte by byte.
bool scalarSlot(const AllocaInst &AI) {
  Type *T = AI.getAllocatedType();
  if (!(T->isIntegerTy() || T->isFloatingPointTy()) || AI.isArrayAllocation())
    return false;
  for (const User *U : AI.users()) {
    if (const auto *LI = dyn_cast<LoadInst>(U)) {
      if (LI->getType() != T)
        return false;
    } else if (const auto *SI = dyn_cast<StoreInst>(U)) {
      if (SI->getPointerOperand() != &AI ||
          SI->getValueOperand()->getType() != T ||
          trackedRoot(rootOf(const_cast<Value *>(SI->getValueOperand()))))
        return false;
    } else if (const auto *II = dyn_cast<IntrinsicInst>(U)) {
      if (!II->isLifetimeStartOrEnd() && !isa<DbgInfoIntrinsic>(II))
        return false;
    } else {
      return false;
    }
  }
  return true;
}

// May-collect sites: every non-intrinsic call or invoke (direct, indirect,
// external C, runtime entry points, calls that do not return) and every
// llvm.cj.* intrinsic still present. NoStackGrow, FastNative,
// gc-leaf-function and noreturn are not no-allocation contracts. Other LLVM
// intrinsics expand inline or become libc/compiler-rt calls, which do not
// allocate managed memory.
bool siteMayCollect(const CallBase &CB) {
  const Function *Callee = CB.getCalledFunction();
  if (!Callee || !Callee->isIntrinsic())
    return true;
  return Callee->getName().startswith("llvm.cj.");
}

// Backward liveness over the tracked roots of one function.
class RootLiveness {
public:
  DenseMap<const Value *, unsigned> Index;
  SmallVector<Value *, 64> Values;
  DenseMap<const BasicBlock *, BitVector> LiveOut;

  unsigned indexOf(const Value *V) const {
    auto It = Index.find(V);
    return It == Index.end() ? ~0u : It->second;
  }
  unsigned rootIndex(Value *V) const { return indexOf(rootOf(V)); }

  void compute(Function &F, ArrayRef<BasicBlock *> RPO) {
    auto Add = [&](Value *V) {
      if (trackedRoot(V) && Index.try_emplace(V, Values.size()).second)
        Values.push_back(V);
    };
    for (Argument &A : F.args())
      Add(&A);
    for (Instruction &I : instructions(F))
      Add(&I);
    const unsigned N = Values.size();
    DenseMap<const BasicBlock *, BitVector> Gen, Kill, LiveIn;
    for (BasicBlock *BB : RPO) {
      BitVector G(N), K(N);
      for (Instruction &I : *BB) {
        if (!isa<PHINode>(I))
          for (Value *Op : I.operands()) {
            unsigned Id = rootIndex(Op);
            if (Id != ~0u && !K.test(Id))
              G.set(Id);
          }
        unsigned Def = indexOf(&I);
        if (Def != ~0u)
          K.set(Def);
      }
      Gen[BB] = std::move(G);
      Kill[BB] = std::move(K);
      LiveIn[BB] = BitVector(N);
      LiveOut[BB] = BitVector(N);
    }
    bool Changed = true;
    while (Changed) {
      Changed = false;
      for (BasicBlock *BB : llvm::reverse(RPO)) {
        BitVector Out(N);
        for (BasicBlock *S : successors(BB)) {
          auto It = LiveIn.find(S);
          if (It != LiveIn.end())
            Out |= It->second;
          for (PHINode &P : S->phis())
            for (unsigned I = 0, E = P.getNumIncomingValues(); I != E; ++I)
              if (P.getIncomingBlock(I) == BB) {
                unsigned Id = rootIndex(P.getIncomingValue(I));
                if (Id != ~0u)
                  Out.set(Id);
              }
        }
        BitVector In = Out;
        In.reset(Kill[BB]);
        In |= Gen[BB];
        if (In != LiveIn[BB] || Out != LiveOut[BB]) {
          LiveIn[BB] = std::move(In);
          LiveOut[BB] = std::move(Out);
          Changed = true;
        }
      }
    }
  }
};

struct Site {
  CallBase *Call;
  BitVector Pub;
};

void unsupportedRoot(Function &F, const Instruction &At, const Twine &Why) {
  F.getContext().emitError(&At, Twine("unsupported WASI root publication in ") +
                                    F.getName() + ": " + Why);
}

// A value that addresses the start of its object: a managed argument, or a
// reference returned by a call (allocation, gcread, runtime entry) or loaded
// from memory.
bool objectStart(const Value *V) {
  return isa<Argument>(V) || isa<CallBase>(V) || isa<LoadInst>(V);
}

bool dominatesSite(const DominatorTree &DT, const Value *V,
                   const Instruction *At) {
  if (isa<Argument>(V))
    return true;
  auto *I = dyn_cast<Instruction>(V);
  return I && DT.dominates(I, At);
}

// I-INB residue: a published PHI/select whose (transitive) incoming chain
// contains a non-inbounds GEP or an inttoptr is only covered when the base of
// that chain is published at the same site. With DT, a base that is an object
// start dominating At but no longer live there (its only use is the derived
// address) is appended to Publish instead: publishing it keeps the object
// alive (rule 4 stores chain roots, not derived addresses).
bool mergedLeavesCovered(Value *R, const BitVector &Pub, const RootLiveness &L,
                         const DominatorTree *DT = nullptr,
                         const Instruction *At = nullptr,
                         SmallVectorImpl<unsigned> *Publish = nullptr) {
  SmallPtrSet<Value *, 16> Seen;
  SmallVector<Value *, 16> Work;
  auto Push = [&](Value *M) {
    if (auto *P = dyn_cast<PHINode>(M))
      for (Value *In : P->incoming_values())
        Work.push_back(In);
    else if (auto *S = dyn_cast<SelectInst>(M)) {
      Work.push_back(S->getTrueValue());
      Work.push_back(S->getFalseValue());
    }
  };
  Seen.insert(R);
  Push(R);
  while (!Work.empty()) {
    Value *V = Work.pop_back_val();
    if (!Seen.insert(V).second)
      continue;
    bool Suspicious = false;
    Value *Cur = V;
    for (unsigned Depth = 0; Depth < 64; ++Depth) {
      if (auto *GEP = dyn_cast<GEPOperator>(Cur)) {
        Suspicious |= !GEP->isInBounds();
        Cur = GEP->getPointerOperand();
      } else if (auto *ITP = dyn_cast<IntToPtrInst>(Cur)) {
        Suspicious = true;
        Cur = rootOf(ITP->getOperand(0));
        break;
      } else if (isa<BitCastOperator>(Cur) || isa<AddrSpaceCastOperator>(Cur) ||
                 isa<PtrToIntOperator>(Cur)) {
        Cur = cast<Operator>(Cur)->getOperand(0);
      } else {
        break;
      }
    }
    if (Suspicious) {
      unsigned Id = L.indexOf(Cur);
      if (Id == ~0u)
        return false;
      if (!Pub.test(Id)) {
        if (!DT || !objectStart(Cur) || !dominatesSite(*DT, Cur, At))
          return false;
        Publish->push_back(Id);
      }
    }
    if (Seen.insert(Cur).second || Cur == V)
      Push(Cur);
  }
  return true;
}

bool hasUnsupportedTransfer(const CallBase &CB) {
  return isa<CallBrInst>(CB) || CB.isInlineAsm() || CB.isMustTailCall() ||
         CB.hasFnAttr(Attribute::ReturnsTwice) ||
         (CB.hasOperandBundles() && siteMayCollect(CB));
}

bool emitFrame(Function &F, Constant *RootTop) {
  Module &M = *F.getParent();
  const DataLayout &DL = M.getDataLayout();
  BasicBlock &Entry = F.getEntryBlock();

  SmallVector<AllocaInst *, 16> Ranges, Dynamic;
  for (Instruction &I : instructions(F)) {
    auto *AI = dyn_cast<AllocaInst>(&I);
    if (!AI || scalarSlot(*AI))
      continue;
    if (AI->getParent() != &Entry || !AI->isStaticAlloca()) {
      Dynamic.push_back(AI);
      continue;
    }
    const TypeSize Size = DL.getTypeAllocSize(AI->getAllocatedType());
    const auto *N = cast<ConstantInt>(AI->getArraySize());
    if (!Size.isScalable() && N->getValue().getActiveBits() <= 32 &&
        Size.getFixedValue() * N->getZExtValue() < DL.getPointerSize(1))
      continue; // too small to hold a reference
    Ranges.push_back(AI);
  }

  SmallVector<BasicBlock *, 32> RPO;
  for (BasicBlock *BB : ReversePostOrderTraversal<Function *>(&F))
    RPO.push_back(BB);
  RootLiveness L;
  L.compute(F, RPO);

  // Publication set of site S = roots still live after S, minus S's own
  // result, plus the roots of all of S's arguments (I-CARG).
  SmallVector<Site, 16> Sites;
  bool AnyPublication = false;
  for (BasicBlock *BB : RPO) {
    BitVector Live = L.LiveOut[BB];
    for (Instruction &I : llvm::reverse(*BB)) {
      if (isa<PHINode>(I))
        break;
      auto *CB = dyn_cast<CallBase>(&I);
      if (CB && siteMayCollect(*CB)) {
        Site S{CB, Live};
        unsigned Def = L.indexOf(CB);
        if (Def != ~0u)
          S.Pub.reset(Def);
        for (Value *Arg : CB->args()) {
          unsigned Id = L.rootIndex(Arg);
          if (Id != ~0u)
            S.Pub.set(Id);
        }
        AnyPublication |= S.Pub.any();
        Sites.push_back(std::move(S));
      }
      unsigned Def = L.indexOf(&I);
      if (Def != ~0u)
        Live.reset(Def);
      for (Value *Op : I.operands()) {
        unsigned Id = L.rootIndex(Op);
        if (Id != ~0u)
          Live.set(Id);
      }
    }
  }
  // A frame is needed iff a collection can happen during this activation and
  // there is something to publish: a non-empty set or a range.
  if (Sites.empty() || (!AnyPublication && Ranges.empty() && Dynamic.empty()))
    return false;

  for (Instruction &I : instructions(F))
    if (auto *CB = dyn_cast<CallBase>(&I))
      if (hasUnsupportedTransfer(*CB)) {
        unsupportedRoot(F, I, "musttail, callbr, inline asm, returns_twice or "
                              "operand bundle in a function with a root frame");
        return false;
      }
  if (!Dynamic.empty()) {
    unsupportedRoot(F, *Dynamic.front(), "dynamic alloca that may hold references");
    return false;
  }
  for (AllocaInst *AI : Ranges) {
    const TypeSize Size = DL.getTypeAllocSize(AI->getAllocatedType());
    const auto *N = cast<ConstantInt>(AI->getArraySize());
    if (Size.isScalable() || N->getValue().getActiveBits() > 32 ||
        (Size.getFixedValue() &&
         N->getZExtValue() > MaxRangeBytes / Size.getFixedValue())) {
      unsupportedRoot(F, *AI, "alloca too large to publish");
      return false;
    }
  }

  // I-INB: publish the dominating object-start base of each merged derived
  // reference that is published at a site but whose base is not.
  {
    DominatorTree DT(F);
    for (Site &S : Sites) {
      SmallVector<unsigned, 4> Publish;
      for (unsigned Id : S.Pub.set_bits()) {
        Value *V = L.Values[Id];
        if (isa<PHINode>(V) || isa<SelectInst>(V))
          (void)mergedLeavesCovered(V, S.Pub, L, &DT, S.Call, &Publish);
      }
      for (unsigned Id : Publish)
        S.Pub.set(Id);
    }
  }

  DenseMap<const Value *, SmallVector<SmallVector<unsigned, 4>, 2>> Leaves;
  size_t Capacity = 0;
  for (const Site &S : Sites) {
    size_t Count = 0;
    for (unsigned Id : S.Pub.set_bits()) {
      Value *V = L.Values[Id];
      auto It = Leaves.find(V);
      if (It == Leaves.end()) {
        SmallVector<unsigned, 4> Path;
        SmallVector<SmallVector<unsigned, 4>, 2> Out;
        if (!managedLeaves(V->getType(), Path, Out)) {
          unsupportedRoot(F, *S.Call, "managed vector live across a call");
          return false;
        }
        It = Leaves.try_emplace(V, std::move(Out)).first;
      }
      if ((isa<PHINode>(V) || isa<SelectInst>(V)) &&
          !mergedLeavesCovered(V, S.Pub, L)) {
        unsupportedRoot(F, *S.Call,
                        Twine("merged derived reference ") + V->getName() +
                            " has a non-inbounds or inttoptr incoming whose "
                            "base is not live (I-INB)");
        return false;
      }
      Count += It->second.size();
    }
    Capacity = std::max(Capacity, Count);
  }

  // Static ranges first in the entry block; the frame code follows them.
  {
    Instruction *Top = &*Entry.getFirstInsertionPt();
    for (AllocaInst *AI : Ranges) {
      if (AI != Top)
        AI->moveBefore(Top);
      else
        Top = AI->getNextNode();
    }
  }
  Instruction *AfterAllocas = &*Entry.getFirstInsertionPt();
  while (isa<AllocaInst>(AfterAllocas))
    AfterAllocas = AfterAllocas->getNextNode();
  IRBuilder<> B(AfterAllocas);
  auto *Raw = B.getInt8PtrTy();
  auto *Ref = B.getInt8PtrTy(1);
  auto *FrameTy = StructType::get(
      Raw, Raw, B.getInt32Ty(), ArrayType::get(Ref, std::max<size_t>(Capacity, 1)));
  AllocaInst *Frame = B.CreateAlloca(FrameTy, nullptr, "wasm.root.frame");
  Value *Desc = ConstantPointerNull::get(Raw);
  if (!Ranges.empty()) {
    auto *RangeTy = StructType::get(Raw, B.getInt32Ty());
    auto *TableTy =
        StructType::get(B.getInt32Ty(), ArrayType::get(RangeTy, Ranges.size()));
    AllocaInst *Table = B.CreateAlloca(TableTy, nullptr, "wasm.root.ranges");
    B.CreateStore(B.getInt32(Ranges.size()), B.CreateStructGEP(TableTy, Table, 0));
    for (size_t I = 0; I < Ranges.size(); ++I) {
      AllocaInst *AI = Ranges[I];
      uint64_t Bytes = DL.getTypeAllocSize(AI->getAllocatedType()) *
                       cast<ConstantInt>(AI->getArraySize())->getZExtValue();
      Value *Start = B.CreateBitCast(AI, Raw);
      // Unwritten stack bytes must not look like references.
      B.CreateMemSet(Start, B.getInt8(0), Bytes, AI->getAlign());
      Value *Slot = B.CreateInBoundsGEP(
          TableTy, Table, {B.getInt32(0), B.getInt32(1), B.getInt32(I)});
      B.CreateStore(Start, B.CreateStructGEP(RangeTy, Slot, 0));
      B.CreateStore(B.getInt32(uint32_t(Bytes)), B.CreateStructGEP(RangeTy, Slot, 1));
    }
    Desc = B.CreateBitCast(Table, Raw);
  }
  // Link: prev = __cj_root_top; __cj_root_top = &frame (I-FRAME).
  Value *Prev = B.CreateLoad(Raw, RootTop, "wasm.root.prev");
  B.CreateStore(Prev, B.CreateStructGEP(FrameTy, Frame, 0));
  B.CreateStore(Desc, B.CreateStructGEP(FrameTy, Frame, 1));
  B.CreateStore(B.getInt32(0), B.CreateStructGEP(FrameTy, Frame, 2));
  B.CreateStore(B.CreateBitCast(Frame, Raw), RootTop);

  for (const Site &S : Sites) {
    B.SetInsertPoint(S.Call);
    uint32_t Slot = 0;
    for (unsigned Id : S.Pub.set_bits()) {
      Value *V = L.Values[Id];
      for (const auto &Path : Leaves.find(V)->second) {
        Value *Leaf = Path.empty() ? V : B.CreateExtractValue(V, Path);
        Value *Address = B.CreateInBoundsGEP(
            FrameTy, Frame, {B.getInt32(0), B.getInt32(3), B.getInt32(Slot++)});
        B.CreateStore(B.CreatePointerBitCastOrAddrSpaceCast(Leaf, Ref), Address);
      }
    }
    B.CreateStore(B.getInt32(Slot), B.CreateStructGEP(FrameTy, Frame, 2));
  }
  // The frame escapes through __cj_root_top: no call of this activation may
  // be a tail call.
  for (Instruction &I : instructions(F))
    if (auto *CI = dyn_cast<CallInst>(&I))
      CI->setTailCallKind(CallInst::TCK_None);
  // Unlink before every return. Unwind paths are handled by
  // restoreRootTopAtLandingPads: a caught exception relinks this frame.
  for (BasicBlock &BB : F)
    if (auto *Ret = dyn_cast<ReturnInst>(BB.getTerminator())) {
      B.SetInsertPoint(Ret);
      B.CreateStore(Prev, RootTop);
    }
  return true;
}
} // namespace

// Cross-package extension registry. Native links every package's
// "InnerTypeExtensions" arrays (@ExternalExtensionDefs /
// @NonExternalExtensionDefs) and "OuterTypeExtensions" arrays into CJ metadata
// sections the loader walks (TypeInfo::TraverseOuterExtensionDefs,
// RegisterOuterTypeExtensions). wasm32 has no CJMetadataInfo emitter,
// so the arrays were emitted as unreferenced private data and wasm-ld dropped
// them: an `extend Int64 <: Hashable` from another package was unreachable and
// CJ_MCC_GetMTable trapped. A private explicit-section array is still removed
// by wasm-ld's --gc-sections (llvm.used only marks the symbol NO_STRIP), so the
// module instead registers each array from a constructor; the constructor
// references the arrays, which keeps them live in every linked object.
static const char *const ExtDefsRegisterFn = "CJ_MCC_WasmRegisterExtensionDefs";
static const char *const ExtDefsCtorName = "cj.wasm.register_extension_defs";

static bool registerExtensionDefs(Module &M) {
  if (M.getFunction(ExtDefsCtorName))
    return false; // the pass may run more than once over a module
  SmallVector<GlobalVariable *, 4> Defs;
  for (GlobalVariable &GV : M.globals()) {
    // Inner: a package's own types and generic templates. Outer: extends of
    // types defined elsewhere (std.core's `extend Int64 <: Hashable`), which
    // the native loader adds to the target's MTable at load.
    if (!(GV.isCJInnerTypeExtensions() || GV.isCJOuterTypeExtensions()) ||
        !GV.hasInitializer())
      continue;
    auto *ATy = dyn_cast<ArrayType>(GV.getValueType());
    if (!ATy || !ATy->getElementType()->isPointerTy())
      report_fatal_error(Twine("cj-wasm-roots: extension defs global '") +
                         GV.getName() + "' is not an array of pointers");
    if (ATy->getNumElements() != 0)
      Defs.push_back(&GV);
  }
  if (Defs.empty())
    return false;
  LLVMContext &C = M.getContext();
  Type *I8P = Type::getInt8PtrTy(C);
  Type *I32 = Type::getInt32Ty(C);
  FunctionCallee Reg = M.getOrInsertFunction(
      ExtDefsRegisterFn,
      FunctionType::get(Type::getVoidTy(C), {I8P, I32}, false));
  Function *Ctor =
      Function::Create(FunctionType::get(Type::getVoidTy(C), false),
                       GlobalValue::InternalLinkage, ExtDefsCtorName, M);
  Ctor->addFnAttr(DoneAttr); // no managed values: nothing to publish
  IRBuilder<> B(BasicBlock::Create(C, "entry", Ctor));
  for (GlobalVariable *GV : Defs) {
    uint64_t N = cast<ArrayType>(GV->getValueType())->getNumElements();
    B.CreateCall(Reg, {B.CreatePointerCast(GV, I8P), ConstantInt::get(I32, N)});
  }
  B.CreateRetVoid();
  appendToGlobalCtors(M, Ctor, /*Priority=*/65535);
  return true;
}

// I-FRAME under unwind (wasm EH, M1): a throw leaves the frames of every
// unwound callee linked on __cj_root_top, so at each landingpad (the
// catch_all entry after wasm lowering) __cj_root_top is reset to this
// activation's own frame, or to the value it had on entry when the function
// links no frame. The store precedes every may-collect call of the handler.
static bool restoreRootTopAtLandingPads(Function &F, Constant *RootTop) {
  SmallVector<LandingPadInst *, 8> Pads;
  for (BasicBlock &BB : F)
    if (LandingPadInst *LP = BB.getLandingPadInst())
      Pads.push_back(LP);
  if (Pads.empty())
    return false;
  BasicBlock &Entry = F.getEntryBlock();
  Value *Own = nullptr;
  for (Instruction &I : Entry)
    if (auto *AI = dyn_cast<AllocaInst>(&I))
      if (AI->getName() == "wasm.root.frame") {
        Own = AI;
        break;
      }
  Type *Raw = Type::getInt8PtrTy(F.getContext());
  if (Own) {
    IRBuilder<> B(cast<AllocaInst>(Own)->getNextNode());
    Own = B.CreateBitCast(Own, Raw, "wasm.root.own");
  } else {
    Instruction *AfterAllocas = &*Entry.getFirstInsertionPt();
    while (isa<AllocaInst>(AfterAllocas))
      AfterAllocas = AfterAllocas->getNextNode();
    IRBuilder<> B(AfterAllocas);
    Own = B.CreateLoad(Raw, RootTop, "wasm.root.entry");
  }
  if (auto *OI = dyn_cast<Instruction>(Own)) {
    // The own-frame value must be defined before the frame is linked and
    // dominate every pad: keep it in the entry block right after its source.
    (void)OI;
  }
  for (LandingPadInst *LP : Pads) {
    IRBuilder<> B(&*LP->getParent()->getFirstInsertionPt());
    B.CreateStore(Own, RootTop);
  }
  return true;
}

PreservedAnalyses CJWasmRootsPass::run(Module &M, ModuleAnalysisManager &) {
  const Triple T(M.getTargetTriple());
  if (T.getArch() != Triple::wasm32 || !T.isOSWASI())
    return PreservedAnalyses::all();
  Constant *RootTop = nullptr;
  bool Changed = registerExtensionDefs(M);
  for (Function &F : M) {
    if (F.isDeclaration() || F.hasFnAttribute(DoneAttr))
      continue;
    if (!RootTop)
      RootTop = M.getOrInsertGlobal("__cj_root_top", Type::getInt8PtrTy(M.getContext()));
    Changed |= emitFrame(F, RootTop);
    Changed |= restoreRootTopAtLandingPads(F, RootTop);
    F.addFnAttr(DoneAttr);
  }
  return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
}
