//===- CJWasmRoots.cpp - Publish live wasm roots after allocation lowering -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CJWasmRoots.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Triple.h"
#include "llvm/Analysis/OptimizationRemarkEmitter.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/DiagnosticHandler.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/Transforms/Utils/ModuleUtils.h"

using namespace llvm;

static cl::opt<unsigned> RequestedVersion("cj-wasm-root-version", cl::Hidden,
    cl::desc("Require a matching wasm Cangjie partition root contract"));
static cl::opt<std::string> ExportReturnBases(
    "cj-wasm-export-return-bases", cl::Hidden,
    cl::desc("Write the per-partition wasm return-base records"));
static cl::opt<std::string> ImportReturnBases(
    "cj-wasm-import-return-bases", cl::Hidden,
    cl::desc("Read return-base records from the selected wasm archive member"));

bool llvm::checkCJWasmRootContract(Module &M) {
  Metadata *Version = M.getModuleFlag("cj.wasm.root.version");
  if (!Version && !RequestedVersion.getNumOccurrences())
    return false;
  auto *N = Version ? mdconst::dyn_extract<ConstantInt>(Version) : nullptr;
  if (!N || !N->getType()->isIntegerTy(32) || !N->isOne() ||
      (RequestedVersion.getNumOccurrences() && RequestedVersion != 1) ||
      Triple(M.getTargetTriple()).getArch() != Triple::wasm32)
    report_fatal_error("missing or incompatible cj.wasm.root.version");
  for (StringRef Name : {"cjw_root_frame_push", "cjw_root_frame_pop",
                         "cjw_root_frame_push_complete",
                         "cjw_root_frame_pop_complete",
                         "cjw_roots_module_complete",
                         "cjw_roots_module_incomplete"})
    if (const auto *Hook = M.getNamedValue(Name))
      if (!Hook->use_empty())
        report_fatal_error("wasm partition already contains transient frames");
  return true;
}

namespace {
constexpr char RootRemarkPass[] = "cj-wasm-roots";
constexpr StringLiteral ReturnBaseHeader = "cj-wasm-return-bases-v1\n";
constexpr size_t MaxReturnBaseBytes = 1024 * 1024;

bool managed(Type *T) {
  auto *PT = dyn_cast<PointerType>(T);
  return PT && PT->getAddressSpace() == 1;
}

bool managed(const Value *V) { return managed(V->getType()); }

bool isRecordName(StringRef Name) {
  return !Name.empty() && Name.find_first_not_of(
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$-") ==
      StringRef::npos;
}

bool hasOrdinaryABI(AttributeList Attrs) {
  for (auto Kind : {Attribute::ByVal, Attribute::ByRef, Attribute::InAlloca,
                    Attribute::Preallocated, Attribute::StructRet,
                    Attribute::InReg, Attribute::Nest, Attribute::SwiftSelf,
                    Attribute::SwiftError, Attribute::SwiftAsync,
                    Attribute::SExt, Attribute::ZExt, Attribute::ReturnsTwice,
                    Attribute::Naked})
    if (Attrs.hasAttrSomewhere(Kind))
      return false;
  return true;
}

bool ordinaryWasmReturn(const Function &F) {
  return !F.isIntrinsic() && !F.hasComdat() && F.getAddressSpace() == 0 &&
         !F.hasDLLImportStorageClass() && !F.hasDLLExportStorageClass() &&
         !F.hasFnAttribute("wasm-import-module") &&
         !F.hasFnAttribute("wasm-import-name") &&
         !F.hasFnAttribute("wasm-export-name") &&
         F.getCallingConv() == CallingConv::C && !F.isVarArg() &&
         managed(F.getReturnType()) && hasOrdinaryABI(F.getAttributes());
}

Function *ordinaryWasmCallee(const CallInst &Call) {
  Function *Callee = Call.getCalledFunction();
  if (!Callee || Call.isMustTailCall() || Call.hasOperandBundles() ||
      Call.getCallingConv() != CallingConv::C ||
      Call.getFunctionType() != Callee->getFunctionType() ||
      !hasOrdinaryABI(Call.getAttributes()) || !ordinaryWasmReturn(*Callee))
    return nullptr;
  return Callee;
}

bool hasUnsupportedWasmControlFlow(const Instruction &I) {
  return I.isEHPad() || isa<InvokeInst, ResumeInst, CallBrInst>(I);
}

bool isConstructorCall(const CallInst &Call) {
  return Call.arg_size() && managed(Call.getArgOperand(0)) &&
         Call.getMetadata("cj.wasm.constructor_receiver");
}

// Establish only identity edges. In particular a projection that was valid
// as a liveness owner need not be an object base at the return boundary.
class ReturnValueProof {
  const SmallPtrSetImpl<Value *> &Origins;
  const SmallPtrSetImpl<const Function *> &ReceiverIdentities;
  bool AllowNull;
  DenseMap<const Value *, bool> Proven;

public:
  ReturnValueProof(const SmallPtrSetImpl<Value *> &Origins,
                   const SmallPtrSetImpl<const Function *> &ReceiverIdentities,
                   bool AllowNull)
      : Origins(Origins), ReceiverIdentities(ReceiverIdentities),
        AllowNull(AllowNull) {}

  bool proves(Value *V, unsigned Depth = 0) {
    if (!managed(V) || Depth == 64)
      return false;
    if (Origins.contains(V) || (AllowNull && isa<ConstantPointerNull>(V)))
      return true;
    auto Entry = Proven.try_emplace(V, false);
    if (!Entry.second)
      return Entry.first->second; // Reject a cycle while proving it.
    auto Proves = [&](Value *Incoming) { return proves(Incoming, Depth + 1); };
    bool Result = false;
    if (auto *Cast = dyn_cast<BitCastOperator>(V))
      Result = Proves(Cast->getOperand(0));
    else if (auto *Phi = dyn_cast<PHINode>(V))
      Result = llvm::all_of(Phi->incoming_values(), Proves);
    else if (auto *Select = dyn_cast<SelectInst>(V))
      Result = isGuaranteedNotToBeUndefOrPoison(Select->getCondition()) &&
               Proves(Select->getTrueValue()) && Proves(Select->getFalseValue());
    else if (auto *Call = dyn_cast<CallInst>(V))
      if (isConstructorCall(*Call) &&
          ReceiverIdentities.contains(ordinaryWasmCallee(*Call)))
        Result = Proves(Call->getArgOperand(0));
    Proven[V] = Result;
    return Result;
  }

  bool provesReturns(Function &F) {
    bool SawReturn = false;
    for (Instruction &I : instructions(F)) {
      if (hasUnsupportedWasmControlFlow(I))
        return false;
      if (auto *Ret = dyn_cast<ReturnInst>(&I)) {
        SawReturn = true;
        if (!proves(Ret->getReturnValue()))
          return false;
      }
    }
    return SawReturn;
  }
};

// ---- complete roots --------------------------------------------------------
// C6 is a non-moving mark-sweep collector. Under the complete contract every
// managed SSA value (an AS1 pointer, or a first-class aggregate holding AS1
// pointers) that is live across a call that may collect, and every managed
// argument of that call, is stored into the function's shadow frame for the
// duration of the call. No value needs to be an object start: the collector
// marks the object containing the address a slot holds and never writes slots
// back, so later uses keep their SSA values. Every alloca that can hold a
// reference is published in place through the frame's range table, so a
// callee that stores into its caller's stack (sret, inout, out parameters) is
// covered as well. A function with a shape outside this contract makes its
// module incomplete; the runtime then never collects.
constexpr uint32_t CompleteFrameFlag = 0x80000000u;
constexpr uint64_t MaxRangeWords = 1u << 24;

bool vectorOfManaged(Type *T) {
  if (auto *VT = dyn_cast<VectorType>(T))
    return managed(VT->getElementType());
  return false;
}

// Index paths of the AS1 leaves of a first-class aggregate. False when the
// aggregate holds managed vectors, which this contract does not publish.
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

// Only a slot read and written as one non-pointer scalar of its own type
// cannot hold a reference. Every other alloca is scanned as a range.
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
          SI->getValueOperand()->getType() != T)
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

bool siteMayCollect(const CallBase &CB) {
  if (CB.isInlineAsm() || CB.doesNotReturn())
    return false;
  if (const auto *CI = dyn_cast<CallInst>(&CB))
    if (CI->isMustTailCall())
      return false;
  const Function *Fn = CB.getCalledFunction();
  if (!Fn)
    return true;
  if (Fn->isIntrinsic())
    return Fn->getName().startswith("llvm.cj.");
  return !Fn->hasFnAttribute("gc-leaf-function");
}

// Backward liveness over the managed SSA values of one function.
class ManagedLiveness {
public:
  DenseMap<const Value *, unsigned> Index;
  SmallVector<Value *, 64> Values;
  DenseMap<const BasicBlock *, BitVector> LiveOut;

  unsigned indexOf(const Value *V) const {
    auto It = Index.find(V);
    return It == Index.end() ? ~0u : It->second;
  }

  void add(Value *V) {
    if (Index.try_emplace(V, Values.size()).second)
      Values.push_back(V);
  }

  void compute(Function &F, ArrayRef<BasicBlock *> RPO) {
    for (Argument &A : F.args())
      if (holdsManaged(A.getType()))
        add(&A);
    for (Instruction &I : instructions(F))
      if (holdsManaged(I.getType()))
        add(&I);
    const unsigned N = Values.size();
    DenseMap<const BasicBlock *, BitVector> Gen, Kill, LiveIn;
    for (BasicBlock *BB : RPO) {
      BitVector G(N), K(N);
      for (Instruction &I : *BB) {
        if (!isa<PHINode>(I))
          for (Value *Op : I.operands()) {
            unsigned Id = indexOf(Op);
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
                unsigned Id = indexOf(P.getIncomingValue(I));
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

struct CompleteSite {
  CallBase *Call;
  BitVector Live;
};

void missedRoot(Function &F, const Instruction *At, StringRef Why) {
  OptimizationRemarkEmitter ORE(&F);
  ORE.emit([&] {
    return At ? OptimizationRemarkMissed(RootRemarkPass, "IncompleteRoots", At)
                    << "wasm roots incomplete: " << Why
              : OptimizationRemarkMissed(RootRemarkPass, "IncompleteRoots",
                                         &F)
                    << "wasm roots incomplete: " << Why;
  });
}
} // namespace

bool CJWasmReturnBases::requested() {
  return ExportReturnBases.getNumOccurrences() ||
         ImportReturnBases.getNumOccurrences();
}

bool CJWasmReturnBases::applies(const Module &M) {
  Triple Target(M.getTargetTriple());
  return Target.getArch() == Triple::wasm32 && Target.isOSWASI() &&
         M.getModuleFlag("cj.wasm.root.version") &&
         M.getContext().supportsTypedPointers();
}

CJWasmReturnBases::CJWasmReturnBases(Module &M, bool Enabled) {
  if (Enabled && ImportReturnBases.getNumOccurrences()) {
    auto File = MemoryBuffer::getFile(ImportReturnBases.getValue());
    if (!File)
      report_fatal_error(Twine("cannot read wasm return bases: ") +
                         File.getError().message());
    StringRef Records = (*File)->getBuffer();
    if (Records.size() > MaxReturnBaseBytes || !Records.endswith("\n") ||
        !Records.consume_front(ReturnBaseHeader))
      report_fatal_error("invalid wasm return-base records");
    while (!Records.empty()) {
      auto Line = Records.split('\n');
      if (!isRecordName(Line.first))
        report_fatal_error("invalid wasm return-base symbol");
      Imports.insert(Line.first);
      Records = Line.second;
    }
  }
  if (!ExportReturnBases.getNumOccurrences())
    return;
  Exports = ReturnBaseHeader.str();
  ExportEnabled = Enabled;
  if (!ExportEnabled)
    return;

  // Check the actual receiver bodies before root lowering can rewrite their
  // returns to reloads. The mark selects candidate calls, not trusted bodies.
  SmallPtrSet<Function *, 8> Candidates;
  for (Function &F : M)
    for (Instruction &I : instructions(F)) {
      const auto *Call = dyn_cast<CallInst>(&I);
      if (!Call || !isConstructorCall(*Call))
        continue;
      auto *Callee = ordinaryWasmCallee(*Call);
      if (Callee && !Callee->isDeclaration() &&
          (Callee->hasLocalLinkage() || Callee->hasExternalLinkage()))
        Candidates.insert(Callee);
    }
  bool Grew;
  do {
    Grew = false;
    for (Function *Callee : Candidates) {
      if (ReceiverIdentities.contains(Callee))
        continue;
      SmallPtrSet<Value *, 1> Receiver{Callee->getArg(0)};
      if (ReturnValueProof(Receiver, ReceiverIdentities, false)
              .provesReturns(*Callee))
        Grew |= ReceiverIdentities.insert(Callee).second;
    }
  } while (Grew);
}

bool CJWasmReturnBases::imports(const CallInst &Call) const {
  if (Imports.empty())
    return false;
  const Function *Callee = ordinaryWasmCallee(Call);
  return Callee && Callee->isDeclaration() && Callee->hasExternalLinkage() &&
         Imports.contains(Callee->getName());
}

bool CJWasmReturnBases::receiverIdentity(const CallInst &Call) const {
  Function *Callee = ordinaryWasmCallee(Call);
  return Callee && ReceiverIdentities.contains(Callee);
}

void CJWasmReturnBases::collect(Function &F, ArrayRef<Value *> HeapObjects) {
  if (!ExportEnabled || !F.hasExternalLinkage() || F.isDeclaration() ||
      !isRecordName(F.getName()) || !ordinaryWasmReturn(F))
    return;
  SmallPtrSet<Value *, 8> Origins;
  for (Value *V : HeapObjects) {
    auto *Call = dyn_cast<CallInst>(V);
    Function *Callee = Call ? ordinaryWasmCallee(*Call) : nullptr;
    if (Callee && Callee->isDeclaration() && Callee->hasExternalLinkage())
      Origins.insert(Call);
  }
  if (!ReturnValueProof(Origins, ReceiverIdentities, true).provesReturns(F))
    return;
  // The driver limits v1 records to 1 MiB. An oversized partition exports
  // no facts rather than passing an incomplete or rejected record set.
  if (F.getName().size() >= MaxReturnBaseBytes - Exports.size()) {
    Exports = ReturnBaseHeader.str();
    ExportEnabled = false;
    return;
  }
  Exports.append(F.getName().data(), F.getName().size());
  Exports.push_back('\n');
}

void CJWasmReturnBases::write() const {
  if (Exports.empty())
    return;
  std::error_code Error;
  raw_fd_ostream Out(ExportReturnBases.getValue(), Error);
  if (Error)
    report_fatal_error(Twine("cannot open wasm return-base output: ") +
                       Error.message());
  Out << Exports;
  Out.close();
  if (Out.has_error()) {
    Error = Out.error();
    Out.clear_error();
    report_fatal_error(Twine("cannot write wasm return bases: ") +
                       Error.message());
  }
}

bool llvm::emitCJWasmRoots(Function &F, bool &Complete) {
  Module &M = *F.getParent();
  const DataLayout &DL = M.getDataLayout();
  BasicBlock &Entry = F.getEntryBlock();
  bool Changed = false;

  for (Instruction &I : instructions(F))
    if (isa<CallBrInst>(I)) {
      missedRoot(F, &I, "callbr");
      Complete = false;
      return false;
    }

  // Static allocas first, so the range table can be filled before any call.
  SmallVector<AllocaInst *, 16> Ranges;
  {
    SmallVector<AllocaInst *, 16> Static;
    for (Instruction &I : instructions(F)) {
      auto *AI = dyn_cast<AllocaInst>(&I);
      if (!AI || scalarSlot(*AI))
        continue;
      if (AI->getParent() != &Entry || !AI->isStaticAlloca()) {
        missedRoot(F, AI, "dynamic alloca that may hold references");
        Complete = false;
        return false;
      }
      Static.push_back(AI);
    }
    Instruction *Top = &*Entry.getFirstInsertionPt();
    for (AllocaInst *AI : Static) {
      if (AI != Top) {
        AI->moveBefore(Top);
        Changed = true;
      } else {
        Top = AI->getNextNode();
      }
      uint64_t Bytes = DL.getTypeAllocSize(AI->getAllocatedType()) *
                       cast<ConstantInt>(AI->getArraySize())->getZExtValue();
      if (Bytes == 0)
        continue;
      if ((Bytes + 3) / 4 > MaxRangeWords) {
        missedRoot(F, AI, "alloca too large to publish");
        Complete = false;
        return false;
      }
      Ranges.push_back(AI);
    }
  }

  SmallVector<BasicBlock *, 32> RPO;
  for (BasicBlock *BB : ReversePostOrderTraversal<Function *>(&F))
    RPO.push_back(BB);

  // Invoke results are defined on the normal edge; give each invoke its own
  // normal destination so the frame can be popped there.
  for (BasicBlock *BB : RPO)
    if (auto *II = dyn_cast<InvokeInst>(BB->getTerminator()))
      if (siteMayCollect(*II) && !II->getNormalDest()->getSinglePredecessor()) {
        SplitEdge(BB, II->getNormalDest());
        Changed = true;
      }
  RPO.clear();
  for (BasicBlock *BB : ReversePostOrderTraversal<Function *>(&F))
    RPO.push_back(BB);

  ManagedLiveness L;
  L.compute(F, RPO);
  SmallVector<CompleteSite, 16> Sites;
  for (BasicBlock *BB : RPO) {
    BitVector Live = L.LiveOut[BB];
    for (Instruction &I : llvm::reverse(*BB)) {
      if (isa<PHINode>(I))
        break;
      auto *CB = dyn_cast<CallBase>(&I);
      if (CB && siteMayCollect(*CB)) {
        CompleteSite S{CB, Live};
        unsigned Def = L.indexOf(CB);
        if (Def != ~0u)
          S.Live.reset(Def);
        for (Value *Arg : CB->args()) {
          unsigned Id = L.indexOf(Arg);
          if (Id != ~0u)
            S.Live.set(Id);
        }
        if (S.Live.any() || !Ranges.empty())
          Sites.push_back(std::move(S));
      }
      unsigned Def = L.indexOf(&I);
      if (Def != ~0u)
        Live.reset(Def);
      for (Value *Op : I.operands()) {
        unsigned Id = L.indexOf(Op);
        if (Id != ~0u)
          Live.set(Id);
      }
    }
  }
  if (Sites.empty())
    return Changed;

  // Leaves of each published value; reject managed vectors.
  DenseMap<const Value *, SmallVector<SmallVector<unsigned, 4>, 2>> Leaves;
  size_t Capacity = 0;
  for (const CompleteSite &S : Sites) {
    size_t Count = 0;
    for (unsigned Id : S.Live.set_bits()) {
      Value *V = L.Values[Id];
      auto It = Leaves.find(V);
      if (It == Leaves.end()) {
        SmallVector<unsigned, 4> Path;
        SmallVector<SmallVector<unsigned, 4>, 2> Out;
        if (!managedLeaves(V->getType(), Path, Out)) {
          missedRoot(F, S.Call, "managed vector live across a call");
          Complete = false;
          return Changed;
        }
        It = Leaves.try_emplace(V, std::move(Out)).first;
      }
      Count += It->second.size();
    }
    Capacity = std::max(Capacity, Count);
  }

  // After every static alloca: the range table refers to all of them.
  Instruction *AfterAllocas = &*Entry.getFirstInsertionPt();
  while (isa<AllocaInst>(AfterAllocas))
    AfterAllocas = AfterAllocas->getNextNode();
  IRBuilder<> B(AfterAllocas);
  auto *Raw = B.getInt8PtrTy();
  auto *Ref = B.getInt8PtrTy(1);
  auto *FrameTy = StructType::get(Raw, Raw, B.getInt32Ty(),
                                  ArrayType::get(Ref, std::max<size_t>(Capacity, 1)));
  AllocaInst *Frame = B.CreateAlloca(FrameTy, nullptr, "wasm.root.frame");
  Value *Handle = B.CreateBitCast(Frame, Raw);
  Value *Desc = ConstantPointerNull::get(Raw);
  if (!Ranges.empty()) {
    auto *RangeTy = StructType::get(Raw, B.getInt32Ty());
    auto *TableTy = StructType::get(B.getInt32Ty(),
                                    ArrayType::get(RangeTy, Ranges.size()));
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
      B.CreateStore(B.getInt32(uint32_t((Bytes + 3) / 4)),
                    B.CreateStructGEP(RangeTy, Slot, 1));
    }
    Desc = B.CreateBitCast(Table, Raw);
  }
  B.CreateStore(Desc, B.CreateStructGEP(FrameTy, Frame, 1));
  auto *HookTy = FunctionType::get(B.getVoidTy(), {Raw}, false);
  FunctionCallee Push = M.getOrInsertFunction("cjw_root_frame_push_complete", HookTy);
  FunctionCallee Pop = M.getOrInsertFunction("cjw_root_frame_pop_complete", HookTy);

  for (const CompleteSite &S : Sites) {
    B.SetInsertPoint(S.Call);
    uint32_t Slot = 0;
    for (unsigned Id : S.Live.set_bits()) {
      Value *V = L.Values[Id];
      for (const auto &Path : Leaves.find(V)->second) {
        Value *Leaf = Path.empty() ? V : B.CreateExtractValue(V, Path);
        Value *Address = B.CreateInBoundsGEP(
            FrameTy, Frame, {B.getInt32(0), B.getInt32(3), B.getInt32(Slot++)});
        B.CreateStore(B.CreatePointerBitCastOrAddrSpaceCast(Leaf, Ref), Address,
                      /*isVolatile=*/true);
      }
    }
    B.CreateStore(B.getInt32(Slot | CompleteFrameFlag),
                  B.CreateStructGEP(FrameTy, Frame, 2), /*isVolatile=*/true);
    B.CreateCall(Push, Handle);
    if (auto *CI = dyn_cast<CallInst>(S.Call)) {
      CI->setTailCallKind(CallInst::TCK_None);
      B.SetInsertPoint(CI->getNextNode());
    } else {
      auto *II = cast<InvokeInst>(S.Call);
      B.SetInsertPoint(&*II->getNormalDest()->getFirstInsertionPt());
    }
    B.CreateCall(Pop, Handle);
  }
  return true;
}

void llvm::emitCJWasmRootRecord(Module &M, bool Complete) {
  LLVMContext &C = M.getContext();
  auto *Raw = Type::getInt8PtrTy(C);
  Constant *Table = ConstantPointerNull::get(Raw);
  if (GlobalVariable *G = M.getGlobalVariable(".cj.wasm.static_roots", true))
    Table = ConstantExpr::getPointerBitCastOrAddrSpaceCast(G, Raw);
  auto *HookTy = FunctionType::get(Type::getVoidTy(C), {Raw}, false);
  FunctionCallee Hook = M.getOrInsertFunction(
      Complete ? "cjw_roots_module_complete" : "cjw_roots_module_incomplete",
      HookTy);
  Function *Ctor = Function::Create(FunctionType::get(Type::getVoidTy(C), false),
                                    GlobalValue::InternalLinkage,
                                    ".cj.wasm.roots_record", M);
  IRBuilder<> B(BasicBlock::Create(C, "entry", Ctor));
  B.CreateCall(Hook, Table);
  B.CreateRetVoid();
  appendToGlobalCtors(M, Ctor, 0);
}
