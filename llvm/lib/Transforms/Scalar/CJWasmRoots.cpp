//===- CJWasmRoots.cpp - Publish live wasm roots after allocation lowering -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CJWasmRoots.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Triple.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Transforms/Scalar/CJGCLiveAnalysis.h"
#include "llvm/Transforms/Utils/PromoteMemToReg.h"

using namespace llvm;

static cl::opt<unsigned> RequestedVersion("cj-wasm-root-version", cl::Hidden,
    cl::desc("Require a matching wasm Cangjie partition root contract"));

bool llvm::checkCJWasmRootContract(Module &M) {
  Metadata *Version = M.getModuleFlag("cj.wasm.root.version");
  if (!Version && !RequestedVersion.getNumOccurrences())
    return false;
  auto *N = Version ? mdconst::dyn_extract<ConstantInt>(Version) : nullptr;
  if (!N || !N->getType()->isIntegerTy(32) || !N->isOne() ||
      (RequestedVersion.getNumOccurrences() && RequestedVersion != 1) ||
      Triple(M.getTargetTriple()).getArch() != Triple::wasm32)
    report_fatal_error("missing or incompatible cj.wasm.root.version");
  for (StringRef Name : {"cjw_root_frame_push", "cjw_root_frame_pop"})
    if (const auto *Hook = M.getNamedValue(Name))
      if (!Hook->use_empty())
        report_fatal_error("wasm partition already contains transient frames");
  return true;
}

namespace {
bool managed(Value *V) {
  auto *PT = dyn_cast<PointerType>(V->getType());
  return PT && PT->getAddressSpace() == 1;
}

// A root is either an actual heap base or the initialized AS1 view returned
// by stack allocation lowering. Only the latter's typed fields go into C6.
using RootMap = DenseMap<Value *, Value *>;
struct Site {
  CallInst *Call;
  SmallVector<Value *, 8> Roots;
  SmallVector<std::pair<Value *, uint64_t>, 4> Fields;
};

bool projection(const Instruction &I) {
  return isa<BitCastInst>(I) || isa<AddrSpaceCastInst>(I) ||
         isa<GetElementPtrInst>(I);
}

bool mayCollect(Instruction &I) {
  auto *CI = dyn_cast<CallInst>(&I);
  if (!CI || CI->isMustTailCall() || CI->doesNotReturn() || CI->isInlineAsm())
    return false;
  Function *Fn = CI->getCalledFunction();
  if (!Fn)
    return true;
  if (Fn->isIntrinsic())
    return Fn->getName().startswith("llvm.cj.");
  return !Fn->hasFnAttribute("gc-leaf-function");
}

// Reuse CJ's backward CFG fixed point, but carry the proven *owner* of each
// operand (including stack views and AS0 projections), not all AS1 values.
class RootLiveness : public GCLiveAnalysis {
  const RootMap &Owners;
  void use(Value *V, LiveSetTy &Live) {
    if (Value *Root = Owners.lookup(V))
      Live.insert(Root);
  }
public:
  RootLiveness(Function &F, DominatorTree &DT, const RootMap &Owners)
      : GCLiveAnalysis(F, DT), Owners(Owners) {}

  void transfer(Instruction &I, LiveSetTy &Live) {
    Live.remove(&I);
    if (isa<PHINode>(I) || isa<DbgInfoIntrinsic>(I))
      return;
    for (Use &U : I.operands())
      use(U, Live);
  }
  void computeLiveInValues(BasicBlock::reverse_iterator B,
                           BasicBlock::reverse_iterator E, LiveSetTy &Live) override {
    for (Instruction &I : make_range(B, E))
      transfer(I, Live);
  }
  void computeLiveOutSeed(BasicBlock *BB, LiveSetTy &Live) override {
    for (BasicBlock *Succ : successors(BB))
      for (PHINode &Phi : Succ->phis())
        use(Phi.getIncomingValueForBlock(BB), Live);
  }
  void computeKillSet(BasicBlock *BB, LiveSetTy &Killed) override {
    for (Instruction &I : *BB)
      if (Owners.lookup(&I) == &I)
        Killed.insert(&I);
  }
};

void addProjections(Value *V, RootMap &Owners) {
  Value *Base = Owners.lookup(V);
  SmallVector<Value *, 8> Work{V};
  while (!Work.empty()) {
    Value *V = Work.pop_back_val();
    for (User *U : V->users()) {
      auto *I = dyn_cast<Instruction>(U);
      if (I && projection(*I) && I->getOperand(0) == V &&
          I->getType()->isPointerTy() && Owners.try_emplace(I, Base).second)
        Work.push_back(I);
    }
  }
}

// A live aggregate need not have all its fields live. Starting at the
// safepoint, follow successors until a read, a complete overwrite, or the
// next initialization of this stack object. At an opaque use (e.g. sret),
// the callee can observe the whole typed payload.
bool liveFieldAt(CallInst *Site, Value *Object, uint64_t Field,
                 const RootMap &Owners, const DataLayout &DL) {
  auto *Storage = cast<AddrSpaceCastInst>(Object)->getOperand(0);
  const uint64_t Width = DL.getPointerSize(1);
  auto access = [&](Value *Ptr, uint64_t Bytes, bool Write) {
    if (Owners.lookup(Ptr) != Object)
      return 0;
    APInt Off(DL.getIndexSizeInBits(0), 0);
    if (Ptr->stripAndAccumulateConstantOffsets(DL, Off, true) != Storage)
      return Write ? 0 : 1;
    int64_t Start = Off.getSExtValue();
    int64_t End = Start + static_cast<int64_t>(Bytes);
    if (Write)
      return Start <= int64_t(Field) && End >= int64_t(Field + Width) ? -1 : 0;
    return End > int64_t(Field) && Start < int64_t(Field + Width) ? 1 : 0;
  };
  SmallVector<Instruction *, 8> Work{Site};
  SmallPtrSet<BasicBlock *, 16> Seen;
  while (!Work.empty()) {
    Instruction *Start = Work.pop_back_val();
    BasicBlock *BB = Start->getParent();
    bool Killed = false;
    for (Instruction &I : make_range(Start->getIterator(), BB->end())) {
      if (&I == Object) {
        Killed = true;
        break;
      }
      if (projection(I) || isa<DbgInfoIntrinsic>(I))
        continue;
      int Effect = 0;
      if (auto *LI = dyn_cast<LoadInst>(&I)) {
        Effect = access(LI->getPointerOperand(), DL.getTypeStoreSize(LI->getType()), false);
      } else if (auto *SI = dyn_cast<StoreInst>(&I)) {
        if (Owners.lookup(SI->getValueOperand()) == Object)
          return true;
        Effect = access(SI->getPointerOperand(),
                        DL.getTypeStoreSize(SI->getValueOperand()->getType()), true);
      } else if (auto *MI = dyn_cast<MemIntrinsic>(&I)) {
        auto *Size = dyn_cast<ConstantInt>(MI->getLength());
        if (auto *Copy = dyn_cast<MemTransferInst>(MI))
          if (Owners.lookup(Copy->getRawSource()) == Object &&
              (!Size || access(Copy->getRawSource(), Size->getLimitedValue(UINT32_MAX), false)))
            return true;
        if (Size)
          Effect = access(MI->getRawDest(), Size->getLimitedValue(UINT32_MAX), true);
      } else {
        for (Use &U : I.operands())
          if (Owners.lookup(U) == Object)
            return true;
      }
      if (Effect > 0)
        return true;
      if (Effect < 0) {
        Killed = true;
        break;
      }
    }
    if (!Killed)
      for (BasicBlock *Succ : successors(BB))
        if (Seen.insert(Succ).second)
          Work.push_back(&Succ->front());
  }
  return false;
}

// A merge can select a proven interior on one edge and an unknown pointer
// on another. Select the root, byte displacement and unknown alternative on
// precisely the original edges. The unknown arm contributes a null slot.
struct MergedPointer {
  Value *Offset;
  Value *Fallback;
  Value *Known;
};
using Merges = DenseMap<Value *, MergedPointer>;
using StackFields = DenseMap<Value *, SmallVector<uint64_t, 4>>;

void collectMerges(Function &F, DominatorTree &DT, RootMap &Owners,
                   const StackFields &Fields, Merges &Recipes) {
  SmallVector<Instruction *, 16> Work;
  for (BasicBlock *BB : ReversePostOrderTraversal<Function *>(&F))
    for (Instruction &I : *BB)
      if (managed(&I) && isa<PHINode, SelectInst>(I) && !Owners.count(&I))
        Work.push_back(&I);
  for (Instruction *I : Work) {
    auto *P = dyn_cast<PHINode>(I);
    auto *S = dyn_cast<SelectInst>(I);
    SmallVector<Value *, 4> Inputs, Bases, Offsets, Unknown, Valid;
    if (P) {
      // A loop recurrence is not an acyclic proof of its own provenance.
      if (llvm::any_of(P->blocks(), [&](BasicBlock *B) {
            return DT.dominates(P->getParent(), B);
          }))
        continue;
      Inputs.append(P->incoming_values().begin(), P->incoming_values().end());
    } else {
      Inputs = {S->getTrueValue(), S->getFalseValue()};
    }
    auto heap = [&](Value *V) -> Value * {
      Value *R = Owners.lookup(V);
      return Fields.count(R) ? nullptr : R;
    };
    if (llvm::none_of(Inputs, heap))
      continue;
    IRBuilder<> B(I);
    auto *Ref = B.getInt8PtrTy(1);
    auto *Int = B.getInt32Ty();
    for (unsigned J = 0; J != Inputs.size(); ++J) {
      Value *V = Inputs[J];
      Value *R = heap(V);
      B.SetInsertPoint(P ? P->getIncomingBlock(J)->getTerminator() : I);
      Bases.push_back(R ? B.CreateBitCast(R, Ref) : ConstantPointerNull::get(Ref));
      Offsets.push_back(R && R != V
          ? B.CreateSub(B.CreatePtrToInt(V, Int), B.CreatePtrToInt(R, Int))
          : B.getInt32(0));
      Value *Known = B.getInt1(R != nullptr);
      for (Value *D = V; R && D != R;) {
        auto It = Recipes.find(D);
        if (It != Recipes.end()) {
          Known = It->second.Known;
          break;
        }
        auto *Step = dyn_cast<Instruction>(D);
        if (!Step || !projection(*Step))
          break;
        D = Step->getOperand(0);
      }
      Unknown.push_back(B.CreateSelect(Known, Constant::getNullValue(I->getType()), V));
      Valid.push_back(Known);
    }
    B.SetInsertPoint(I);
    auto merge = [&](ArrayRef<Value *> Vs, StringRef Name) -> Value * {
      if (llvm::all_of(Vs, [&](Value *V) { return V == Vs.front(); }))
        return Vs.front();
      if (S)
        return B.CreateSelect(S->getCondition(), Vs[0], Vs[1], Name);
      auto *Phi = B.CreatePHI(Vs.front()->getType(), Vs.size(), Name);
      for (unsigned J = 0; J < Vs.size(); ++J)
        Phi->addIncoming(Vs[J], P->getIncomingBlock(J));
      return Phi;
    };
    Value *Base = merge(Bases, "wasm.root.base");
    if (auto *Origin = Owners.lookup(Base))
      Base = Origin;
    else
      Owners[Base] = Base;
    Owners[I] = Base;
    Recipes[I] = {merge(Offsets, "wasm.root.offset"),
                  merge(Unknown, "wasm.root.unknown"), merge(Valid, "wasm.root.known")};
    addProjections(I, Owners);

  }
}

// Rebuild a chain of casts/GEPs at its consumer. Dynamic indices are the
// original SSA values; no heap interior is ever placed in a frame slot.
Value *materialize(Value *V, Value *Base, AllocaInst *Current, Instruction *At,
                   const Merges &Recipes) {
  IRBuilder<> B(At);
  Value *Result = B.CreateLoad(Base->getType(), Current);
  SmallVector<Instruction *, 4> Steps;
  while (V != Base) {
    auto It = Recipes.find(V);
    if (It != Recipes.end()) {
      auto &R = It->second;
      Result = B.CreateGEP(B.getInt8Ty(), B.CreateBitCast(Result, B.getInt8PtrTy(1)),
                           R.Offset, "wasm.root.interior");
      Result = B.CreateSelect(R.Known, B.CreateBitCast(Result, V->getType()), R.Fallback);
      break;
    }
    auto *I = cast<Instruction>(V);
    Steps.push_back(I);
    V = I->getOperand(0);
  }
  for (Instruction *I : reverse(Steps)) {
    Instruction *Copy = I->clone();
    Copy->setOperand(0, Result);
    Result = B.Insert(Copy, I->getName() + ".rebased");
  }
  return Result;
}
} // namespace

bool llvm::emitCJWasmRoots(Function &F, ArrayRef<Value *> HeapObjects,
                           ArrayRef<Value *> StackObjects) {
  Module &M = *F.getParent();
  RootMap Owners;
  StackFields Fields;
  for (Value *V : HeapObjects)
    Owners[V] = V;
  for (Argument &A : F.args())
    if (managed(&A) && F.getAttributes().hasParamAttr(A.getArgNo(), "cj.wasm.base"))
      Owners[&A] = &A;
  for (Value *V : StackObjects) {
    auto *AI = cast<AllocaInst>(cast<AddrSpaceCastInst>(V)->getOperand(0));
    MapVector<uint64_t, bool> Layout;
    computeStructTypeOffsets(cast<StructType>(AI->getAllocatedType()), Layout,
                             M.getDataLayout());
    for (auto P : Layout)
      if (P.second)
        Fields[V].push_back(P.first);
    if (Fields.count(V))
      Owners[V] = V;
  }
  SmallVector<CallInst *, 4> Constructors;
  for (Instruction &I : instructions(F)) {
    // C6 has no EH cleanup path. Match the scope of the existing wasm ABI.
    if (I.isEHPad() || isa<InvokeInst, ResumeInst, CallBrInst>(I))
      return false;
    auto *CI = dyn_cast<CallInst>(&I);
    if (!CI || !managed(CI))
      continue;
    Function *Fn = CI->getCalledFunction();
    if (Fn && Fn->getAttributes().hasRetAttr("cj.wasm.base"))
      Owners[CI] = CI;
    else if (Fn && CI->arg_size() && CI->getMetadata("cj.wasm.constructor_receiver"))
      Constructors.push_back(CI);
  }
  if (Owners.empty())
    return false;
  auto isHeapBase = [&](Value *V) {
    V = V->stripPointerCasts();
    return isa<ConstantPointerNull>(V) ||
           (Owners.lookup(V) == V && !Fields.count(V));
  };
  // Constructors return their incoming object only for the frontend's
  // explicit receiver contract. A forwarded interior is still an interior.
  bool Grew;
  do {
    Grew = false;
    for (CallInst *CI : Constructors)
      if (isHeapBase(CI->getArgOperand(0)))
        Grew |= Owners.try_emplace(CI, CI).second;
    for (Instruction &I : instructions(F)) {
      if (!managed(&I) || Owners.count(&I))
        continue;
      if (auto *P = dyn_cast<PHINode>(&I)) {
        if (llvm::all_of(P->incoming_values(), isHeapBase))
          Grew |= Owners.try_emplace(P, P).second;
      } else if (auto *S = dyn_cast<SelectInst>(&I)) {
        if (isHeapBase(S->getTrueValue()) && isHeapBase(S->getFalseValue()))
          Grew |= Owners.try_emplace(S, S).second;
      }
    }
  } while (Grew);

  SmallVector<Value *, 16> Bases;
  for (auto P : Owners)
    Bases.push_back(P.first);
  for (Value *Base : Bases)
    addProjections(Base, Owners);
  DominatorTree DT(F);
  Merges Recipes;
  collectMerges(F, DT, Owners, Fields, Recipes);
  RootLiveness L(F, DT, Owners);
  L.computeLiveness();
  SmallVector<Site, 16> Sites;
  size_t Capacity = 0;
  SetVector<Value *> Needed;
  for (BasicBlock &BB : F) {
    if (!DT.isReachableFromEntry(&BB))
      continue;
    LiveSetTy Live = L.Data.LiveOut[&BB];
    for (Instruction &I : reverse(BB)) {
      L.transfer(I, Live);
      if (!mayCollect(I) || Live.empty())
        continue;
      Site S{cast<CallInst>(&I), {}, {}};
      for (Value *V : Live) {
        auto It = Fields.find(V);
        if (It == Fields.end()) {
          S.Roots.push_back(V);
          Needed.insert(V);
        } else {
          for (uint64_t Field : It->second)
            if (liveFieldAt(S.Call, V, Field, Owners, M.getDataLayout()))
              S.Fields.emplace_back(V, Field);
        }
      }
      size_t Count = S.Roots.size() + S.Fields.size();
      if (Count) {
        Capacity = std::max(Count, Capacity);
        Sites.push_back(std::move(S));
      }
    }
  }
  if (Sites.empty())
    return !Recipes.empty();

  // Snapshot original consumers before inserting any frame/spill operands.
  SmallVector<Use *, 32> Uses;
  for (Instruction &I : instructions(F)) {
    if (isa<DbgInfoIntrinsic>(I))
      continue;
    for (Use &U : I.operands())
      if (Needed.contains(Owners.lookup(U)) &&
          !(projection(I) && Owners.count(&I)))
        Uses.push_back(&U);
  }
  Instruction *Entry = &*F.getEntryBlock().getFirstInsertionPt();
  IRBuilder<> B(Entry);
  auto *Raw = B.getInt8PtrTy();
  auto *Ref = B.getInt8PtrTy(1);
  auto *Slots = ArrayType::get(Ref, Capacity);
  auto *Ty = StructType::get(Raw, Raw, B.getInt32Ty(), Slots);
  Value *Frame = B.CreateAlloca(Ty, nullptr, "wasm.root.frame");
  Value *Handle = B.CreateBitCast(Frame, Raw);
  auto *HookTy = FunctionType::get(B.getVoidTy(), {Raw}, false);
  auto Push = M.getOrInsertFunction("cjw_root_frame_push", HookTy);
  auto Pop = M.getOrInsertFunction("cjw_root_frame_pop", HookTy);
  DenseMap<Value *, AllocaInst *> Current;
  SmallVector<AllocaInst *, 8> Promote;
  for (Value *V : Needed) {
    B.SetInsertPoint(Entry);
    auto *A = B.CreateAlloca(V->getType(), nullptr, "wasm.root.current");
    Current[V] = A;
    Promote.push_back(A);
    if (auto *I = dyn_cast<Instruction>(V))
      B.SetInsertPoint(isa<PHINode>(I) ? &*I->getParent()->getFirstInsertionPt()
                                        : I->getNextNode());
    B.CreateStore(V, A);
  }
  for (Use *U : Uses) {
    Instruction *At = cast<Instruction>(U->getUser());
    if (auto *P = dyn_cast<PHINode>(At))
      At = P->getIncomingBlock(*U)->getTerminator();
    Value *Base = Owners.lookup(U->get());
    U->set(materialize(U->get(), Base, Current.lookup(Base), At, Recipes));
  }
  // Reuse the frame storage across disjoint calls, with exactly the live
  // prefix visible. The call result is defined after its own frame is popped.
  for (const Site &S : Sites) {
    B.SetInsertPoint(S.Call);
    B.CreateStore(ConstantPointerNull::get(Raw), B.CreateStructGEP(Ty, Frame, 1));
    struct Slot { Value *Address, *Cell, *Original; bool IsField; };
    SmallVector<Slot, 8> Published;
    auto publish = [&](Value *Cell, bool IsField) {
      Type *T = Cell->getType()->getNonOpaquePointerElementType();
      Value *V = B.CreateAlignedLoad(T, Cell, Align(1));
      Value *Address = B.CreateInBoundsGEP(Ty, Frame,
          {B.getInt32(0), B.getInt32(3), B.getInt32(Published.size())});
      Address = B.CreateBitCast(Address, T->getPointerTo());
      B.CreateStore(V, Address, true);
      Published.push_back({Address, Cell, V, IsField});
    };
    for (Value *V : S.Roots)
      publish(Current.lookup(V), false);
    for (const auto &Field : S.Fields) {
      auto *AI = cast<AddrSpaceCastInst>(Field.first)->getOperand(0);
      Value *P = B.CreateConstGEP1_64(B.getInt8Ty(), B.CreateBitCast(AI, Raw),
                                      Field.second);
      publish(B.CreateBitCast(P, Ref->getPointerTo()), true);
    }
    B.CreateStore(B.getInt32(Published.size()), B.CreateStructGEP(Ty, Frame, 2));
    B.CreateCall(Push, Handle);
    S.Call->setTailCallKind(CallInst::TCK_None);
    B.SetInsertPoint(S.Call->getNextNode());
    for (const Slot &R : Published) {
      auto *T = R.Original->getType();
      Value *Reload = B.CreateLoad(T, R.Address, true, "wasm.root.reload");
      if (R.IsField) {
        // An sret callee can overwrite its caller's payload. Preserve a new
        // field value; a shadow copy can update only the value it represented.
        Value *Now = B.CreateAlignedLoad(T, R.Cell, Align(1));
        Reload = B.CreateSelect(B.CreateICmpEQ(Now, R.Original), Reload, Now);
      }
      B.CreateAlignedStore(Reload, R.Cell, Align(1));
    }
    B.CreateCall(Pop, Handle);
  }
  PromoteMemToReg(Promote, DT);
  return true;
}
