//===- CJExceptionTailOutline.cpp - outline cold throw tails ----*- C++ -*-===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// A cangjie throw site is a self contained cold sequence:
//   %obj = call @CJ_MCC_NewObject(...)
//   %updated = call @exception_ctor(%obj, [msg,] %ti)
//   call @CJ_MCC_ThrowException(%updated)
//   unreachable
// and every site carries its own copy of it. This pass rewrites the sequence to
// a call of one helper shared by every site that uses the same
// constructor signature, so the hot path keeps a single call and the sequence
// is emitted once.
//
// Sites that build the exception through a runtime factory
//   %obj = call @rt$Create...Exception_msg(msg)
//   call @CJ_MCC_ThrowException(%obj)
//   unreachable
// are outlined the same way, with one helper shared per factory signature.
//
// See CJExceptionTailOutline.h for why the pass runs after inlining.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/CJExceptionTailOutline.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Triple.h"
#include "llvm/Analysis/TargetLibraryInfo.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/ValueHandle.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Transforms/Utils/Local.h"

#include <string>

using namespace llvm;

namespace llvm {

extern cl::opt<bool> CJLTOOpt;

cl::opt<bool>
    EnableCJExceptionTailExtract("enable-cangjie-exception-tail-extract",
                                 cl::init(true), cl::ReallyHidden);

} // namespace llvm

namespace {

// The `$` keeps these names out of reach of user code: a Cangjie identifier
// cannot contain it (only macro quotes produce DOLLAR_IDENTIFIER), and an `@C`
// export uses the identifier verbatim, so no user declared symbol can ever
// equal one of them.
const static StringRef ExceptionCtor0MangleStr = "__cj$exception_tail_helper0";
const static StringRef ExceptionCtorStringMangleStr =
    "__cj$exception_tail_helper_string";
const static StringRef ExceptionFactoryMangleStr =
    "__cj$exception_tail_helper_factory";

/// Rewrites the cold throw tails of one module to shared helpers.
class CJExceptionTailOutliner {
public:
  explicit CJExceptionTailOutliner(Module &M) : M(M), C(M.getContext()) {}

  bool extractExceptionTails(Function &F) {
    if (!EnableCJExceptionTailExtract ||
        Triple(F.getParent()->getTargetTriple()).isOSWindows() ||
        isLTOCompileMode())
      return false;

    SmallVector<CallInst *, 8> ThrowCalls;
    for (Instruction &I : instructions(F)) {
      auto *CI = dyn_cast<CallInst>(&I);
      if (!CI || CI->getCalledFunction() == nullptr)
        continue;
      if (!CI->getCalledFunction()->getName().equals("CJ_MCC_ThrowException"))
        continue;
      if (!isa<UnreachableInst>(CI->getNextNode()))
        continue;
      ThrowCalls.push_back(CI);
    }

    bool Changed = false;
    for (CallInst *ThrowCI : ThrowCalls) {
      // The worklist is collected before we rewrite the function. Skip any
      // entry that has already been removed while processing an earlier tail.
      if (ThrowCI->getParent() == nullptr)
        continue;
      Changed |= tryExtractExceptionTail(ThrowCI);
    }
    return Changed;
  }

private:
  // Helpers use the ordinary C ABI. FunctionType does not encode a calling
  // convention or parameter/return attributes, so matching types alone cannot
  // justify replacing a call with a new indirect call in a shared helper.
  static bool hasOrdinaryCallABI(const CallInst *CI) {
    const Function *Callee = CI->getCalledFunction();
    if (!Callee || CI->getCallingConv() != CallingConv::C ||
        Callee->getCallingConv() != CallingConv::C ||
        CI->getFunctionType()->isVarArg() || CI->hasOperandBundles() ||
        CI->isMustTailCall() || CI->isConvergent() ||
        CI->hasFnAttr(Attribute::NoDuplicate) ||
        CI->hasFnAttr(Attribute::ReturnsTwice))
      return false;
    auto HasArgumentABI = [CI](AttributeList Attrs) {
      if (Attrs.getRetAttrs().hasAttributes())
        return true;
      for (unsigned I = 0, E = CI->arg_size(); I < E; ++I)
        if (Attrs.getParamAttrs(I).hasAttributes())
          return true;
      return false;
    };
    return !HasArgumentABI(CI->getAttributes()) &&
           !HasArgumentABI(Callee->getAttributes());
  }

  bool isLTOModule() const {
    if (M.getModuleIdentifier() == "ld-temp.o")
      return true;
    return M.getModuleFlag("ThinLTO") != nullptr;
  }

  bool hasCommandLineFlag(StringRef Name) const {
    auto &Opts = cl::getRegisteredOptions();
    auto It = Opts.find(Name);
    return It != Opts.end() && It->second->getNumOccurrences() > 0;
  }

  bool isLTOCompileMode() const {
    return CJLTOOpt || hasCommandLineFlag("cangjie-lto") || isLTOModule();
  }

  /// An exception constructor's trailing operand is only a type info when it
  /// really has that type. Constructors such as `Ex(obj, msg)` take a String
  /// there instead, and treating it as a type info builds a helper with the
  /// wrong ABI.
  ///
  /// Only the canonical address-space-zero TypeInfo shape is supported. The
  /// helper forwards this constructor operand without interpreting its value.
  bool isTypeInfoPtr(Type *Ty) const {
    auto *PtrTy = dyn_cast<PointerType>(Ty);
    if (!PtrTy || PtrTy->getAddressSpace() != 0)
      return false;
    auto *StructTy =
        dyn_cast<StructType>(PtrTy->getNonOpaquePointerElementType());
    return StructTy != nullptr && StructTy->hasName() &&
           StructTy->getName().equals("TypeInfo");
  }

  bool isStdCoreStringPtr(Type *Ty) const {
    auto *PtrTy = dyn_cast<PointerType>(Ty);
    if (!PtrTy)
      return false;
    auto *StructTy =
        dyn_cast<StructType>(PtrTy->getNonOpaquePointerElementType());
    return StructTy != nullptr && StructTy->hasName() &&
           StructTy->getName().equals("record.std.core:String");
  }

  enum class ExceptionTailHelperKind {
    Ctor0,
    CtorString,
    Factory,
  };

  StringRef getExceptionTailHelperName(ExceptionTailHelperKind Kind) const {
    switch (Kind) {
    case ExceptionTailHelperKind::Ctor0:
      return ExceptionCtor0MangleStr;
    case ExceptionTailHelperKind::CtorString:
      return ExceptionCtorStringMangleStr;
    case ExceptionTailHelperKind::Factory:
      return ExceptionFactoryMangleStr;
    }
    llvm_unreachable("unknown exception tail helper kind");
  }

  void initializeExceptionTailHelper(Function &Func, Function &Caller) {
    Func.addFnAttr(Attribute::NoReturn);
    Func.addFnAttr(Attribute::NoInline);
    Func.addFnAttr(Attribute::Cold);
    Func.addFnAttr(Attribute::OptimizeForSize);
    Func.addFnAttr(Attribute::MinSize);
    Func.setGC("cangjie");
    if (Caller.hasPersonalityFn())
      Func.setPersonalityFn(Caller.getPersonalityFn());
    else if (Function *Personality = M.getFunction("__cj_personality_v0$"))
      Func.setPersonalityFn(Personality);
  }

  Function *getOrInsertNewObjectFunc() {
    auto *RefTy = Type::getInt8PtrTy(C, 1);
    auto *NewObjTy = FunctionType::get(
        RefTy, {Type::getInt8PtrTy(C), Type::getInt32Ty(C)}, false);
    Function *NewObjFunc = M.getFunction("CJ_MCC_NewObject");
    if (NewObjFunc == nullptr)
      NewObjFunc =
          M.declareCJRuntimeFunc("CJ_MCC_NewObject", NewObjTy, false, true);
    return NewObjFunc;
  }

  Function *getOrInsertThrowExceptionFunc() {
    auto *RefTy = Type::getInt8PtrTy(C, 1);
    auto *ThrowTy = FunctionType::get(Type::getVoidTy(C), {RefTy}, false);
    Function *ThrowFunc = M.getFunction("CJ_MCC_ThrowException");
    if (ThrowFunc == nullptr)
      ThrowFunc = M.declareCJRuntimeFunc("CJ_MCC_ThrowException", ThrowTy,
                                         false, false);
    return ThrowFunc;
  }

  void buildExceptionTailHelperBody(Function &Func,
                                    ExceptionTailHelperKind Kind,
                                    PointerType *TypeInfoTy, Type *MsgTy,
                                    Type *CtorRetTy) {
    auto *RefTy = Type::getInt8PtrTy(C, 1);
    Function *NewObjFunc = getOrInsertNewObjectFunc();
    Function *ThrowFunc = getOrInsertThrowExceptionFunc();

    auto ArgIt = Func.arg_begin();
    Argument *AllocTypeInfo = &*ArgIt++;
    AllocTypeInfo->setName("alloc_ti");
    Argument *AllocSize = &*ArgIt++;
    AllocSize->setName("alloc_size");
    Argument *Ctor = &*ArgIt++;
    Ctor->setName("ctor");
    Argument *TypeInfo = &*ArgIt++;
    TypeInfo->setName("ctor_ti");
    Argument *Msg = nullptr;
    if (Kind == ExceptionTailHelperKind::CtorString) {
      Msg = &*ArgIt++;
      Msg->setName("msg");
    }

    BasicBlock *Entry = BasicBlock::Create(C, "entry", &Func);
    IRBuilder<> IRB(Entry);
    // Allocation and construction have independent inputs. In particular the
    // constructor may ignore a null/poison TypeInfo, and its TypeInfo need not
    // describe this allocation. Preserve the actual allocation size too; do
    // not introduce a load or recompute it from constructor metadata.
    Value *Obj =
        IRB.CreateCall(NewObjFunc, {AllocTypeInfo, AllocSize}, "obj");
    CallInst *Initialized;
    if (Kind == ExceptionTailHelperKind::Ctor0) {
      auto *CtorTy =
          FunctionType::get(CtorRetTy, {RefTy, TypeInfoTy}, false);
      Initialized = IRB.CreateCall(CtorTy, Ctor, {Obj, TypeInfo});
    } else {
      auto *CtorTy = FunctionType::get(CtorRetTy,
                                      {RefTy, MsgTy, TypeInfoTy}, false);
      Initialized = IRB.CreateCall(CtorTy, Ctor, {Obj, Msg, TypeInfo});
    }
    // Registration may relocate the receiver. The managed constructor's
    // returned reference, not its input allocation, is the throw operand.
    Value *Thrown = CtorRetTy->isVoidTy() ? Obj : Initialized;
    IRB.CreateCall(ThrowFunc, {Thrown});
    IRB.CreateUnreachable();
  }

  Function *getOrInsertExceptionTailFunc(ExceptionTailHelperKind Kind,
                                         PointerType *TypeInfoTy, Type *MsgTy,
                                         Type *CtorRetTy, Function &Caller) {
    auto *RefTy = Type::getInt8PtrTy(C, 1);
    SmallVector<Type *, 3> CtorArgTys{RefTy};
    if (Kind == ExceptionTailHelperKind::CtorString)
      CtorArgTys.push_back(MsgTy);
    CtorArgTys.push_back(TypeInfoTy);
    auto *CtorTy = FunctionType::get(CtorRetTy, CtorArgTys, false);
    // Helper ABI (the _ref variants use ref-returning constructor pointers):
    //   helper0(i8* allocTI, i32 size, void (ref, TypeInfo*)*, TypeInfo*)
    //   helper_string(i8* allocTI, i32 size,
    //                 void (ref, String*, TypeInfo*)*, TypeInfo*, String*)
    SmallVector<Type *, 5> HelperArgTys{Type::getInt8PtrTy(C),
                                       Type::getInt32Ty(C),
                                       PointerType::getUnqual(CtorTy), TypeInfoTy};
    if (Kind == ExceptionTailHelperKind::CtorString)
      HelperArgTys.push_back(MsgTy);
    auto *FT = FunctionType::get(Type::getVoidTy(C), HelperArgTys, false);

    // Void and ref-returning constructors have different indirect-call ABIs.
    // Keep separate helpers so module traversal order cannot suppress either.
    std::string Name = getExceptionTailHelperName(Kind).str();
    if (!CtorRetTy->isVoidTy())
      Name += "_ref";
    Function *Func = M.getFunction(Name);
    if (Func == nullptr) {
      Func = Function::Create(FT, GlobalValue::InternalLinkage, Name, &M);
      initializeExceptionTailHelper(*Func, Caller);
      buildExceptionTailHelperBody(*Func, Kind, TypeInfoTy, MsgTy, CtorRetTy);
    } else if (Func->getFunctionType() != FT) {
      // One helper is shared per kind, so a call site whose types disagree with
      // the helper already built cannot use it. Leave that tail alone.
      return nullptr;
    }
    return Func;
  }

  /// Body of the factory helper: everything the factory needs to run, then the
  /// throw of whatever object it handed back.
  void buildFactoryTailHelperBody(Function &Func, FunctionType *FactoryTy) {
    auto *RefTy = Type::getInt8PtrTy(C, 1);
    Function *ThrowFunc = getOrInsertThrowExceptionFunc();
    BasicBlock *Entry = BasicBlock::Create(C, "entry", &Func);
    IRBuilder<> IRB(Entry);

    // The helper ABI is the factory's own argument list followed by the factory
    // it has to call, so every site whose factory takes the same arguments can
    // share one helper no matter which exception it throws.
    SmallVector<Value *, 4> Args;
    auto ArgIt = Func.arg_begin();
    for (unsigned I = 0, E = Func.arg_size() - 1; I != E; ++I, ++ArgIt)
      Args.push_back(&*ArgIt);
    Argument *Factory = &*ArgIt;
    Factory->setName("factory");

    Value *Obj = IRB.CreateCall(FactoryTy, Factory, Args, "obj");
    if (Obj->getType() != RefTy)
      Obj = IRB.CreateBitCast(Obj, RefTy);
    IRB.CreateCall(ThrowFunc, {Obj});
    IRB.CreateUnreachable();
  }

  Function *getOrInsertFactoryTailFunc(FunctionType *FactoryTy,
                                       Function &Caller) {
    SmallVector<Type *, 4> HelperArgTys(FactoryTy->param_begin(),
                                        FactoryTy->param_end());
    HelperArgTys.push_back(PointerType::getUnqual(FactoryTy));
    auto *FT = FunctionType::get(Type::getVoidTy(C), HelperArgTys, false);

    StringRef Name =
        getExceptionTailHelperName(ExceptionTailHelperKind::Factory);
    Function *Func = M.getFunction(Name);
    if (Func == nullptr) {
      Func = Function::Create(FT, GlobalValue::InternalLinkage, Name, &M);
      initializeExceptionTailHelper(*Func, Caller);
      buildFactoryTailHelperBody(*Func, FactoryTy);
    } else if (Func->getFunctionType() != FT) {
      // One helper is shared per factory signature, so a call site whose
      // factory shape disagrees with the helper already built cannot use it.
      return nullptr;
    }
    return Func;
  }

  /// `rt$Create...Exception_msg` builds the exception object and returns it so
  /// that the caller can throw it. The pair is a cold tail of the same kind as
  /// the NewObject/ctor one, but the allocation lives inside the factory, so
  /// the helper only has to call the factory and throw its result.
  bool tryExtractFactoryTail(CallInst *ThrowCI, CallInst *FactoryCall) {
    // The object must feed the throw and nothing else, otherwise erasing the
    // call would drop the value another instruction still needs.
    if (FactoryCall->getNumUses() != 1 ||
        !hasOrdinaryCallABI(FactoryCall))
      return false;
    // The helper moves the factory call next to the throw, so the tail has to
    // be one self contained cold block.
    if (FactoryCall->getParent() != ThrowCI->getParent() ||
        FactoryCall->getNextNonDebugInstruction() != ThrowCI)
      return false;
    if (ThrowCI->getArgOperand(0) != FactoryCall)
      return false;
    if (FactoryCall->getFunctionType()->isVarArg())
      return false;
    // Operand bundles would be dropped with the call, and they carry meaning of
    // their own (the gc-live set of a statepoint in particular).
    if (FactoryCall->hasOperandBundles())
      return false;

    Function *Helper =
        getOrInsertFactoryTailFunc(FactoryCall->getFunctionType(),
                                   *ThrowCI->getFunction());
    if (Helper == nullptr)
      return false;

    SmallVector<Value *, 4> HelperArgs;
    for (Value *Arg : FactoryCall->args())
      HelperArgs.push_back(Arg);
    HelperArgs.push_back(FactoryCall->getCalledOperand());

    IRBuilder<> IRB(ThrowCI);
    auto *HelperCall = IRB.CreateCall(Helper, HelperArgs);
    HelperCall->setDebugLoc(ThrowCI->getDebugLoc());
    HelperCall->setDoesNotReturn();

    ThrowCI->eraseFromParent();
    FactoryCall->eraseFromParent();
    return true;
  }

  /// `rt$Create*Exception*_msg` is the runtime shape that allocates and
  /// initialises an exception in one call and hands the object back to the
  /// caller. Anything thrown straight after such a call is the cold tail of
  /// the caller.
  static bool isExceptionFactoryCall(const CallInst *CI) {
    const Function *Callee = CI->getCalledFunction();
    if (Callee == nullptr)
      return false;
    StringRef Name = Callee->getName();
    return Name.startswith("rt$Create") && Name.endswith("_msg");
  }

  bool tryExtractExceptionTail(CallInst *ThrowCI) {
    // Match the canonical cold throw tail:
    //   %obj = call @CJ_MCC_NewObject(...)
    //   call @exception_ctor(%obj, [msg,] %ti)
    //   call @CJ_MCC_ThrowException(%obj)
    //   unreachable
    //
    // Replacing the tail with a helper call keeps the hot path small and lets
    // the backend see one shared cold sequence instead of N duplicated blocks.
    auto *RefTy = Type::getInt8PtrTy(C, 1);
    auto *ThrowTy = FunctionType::get(Type::getVoidTy(C), {RefTy}, false);
    if (!hasOrdinaryCallABI(ThrowCI) ||
        ThrowCI->getFunctionType() != ThrowTy)
      return false;
    StringRef FuncName = ThrowCI->getFunction()->getName();
    if (FuncName.equals(ExceptionCtor0MangleStr) ||
        FuncName.equals(ExceptionCtorStringMangleStr) ||
        FuncName.equals(ExceptionFactoryMangleStr) ||
        FuncName.equals("__cj$exception_tail_helper0_ref") ||
        FuncName.equals("__cj$exception_tail_helper_string_ref"))
      return false;

    // The factory shape has no NewObject/ctor pair to share, the throw of the
    // object it returns is the whole tail.
    if (auto *FactoryCall = dyn_cast<CallInst>(ThrowCI->getArgOperand(0)))
      if (isExceptionFactoryCall(FactoryCall))
        return tryExtractFactoryTail(ThrowCI, FactoryCall);

    // Resolve the constructor first: a managed class constructor returns the
    // possibly updated receiver. Legacy void tails throw the allocation itself.
    // Both forms must remain adjacent and entirely owned by this tail.
    auto *CtorCall = dyn_cast_or_null<CallInst>(
        ThrowCI->getPrevNonDebugInstruction());
    if (!CtorCall || !hasOrdinaryCallABI(CtorCall) || CtorCall->arg_empty())
      return false;
    bool ReturnsRef = CtorCall->getType() == RefTy;
    if (!ReturnsRef && !CtorCall->getType()->isVoidTy())
      return false;
    auto *NewObjCall = dyn_cast<CallInst>(CtorCall->getArgOperand(0));
    if (!NewObjCall || !NewObjCall->getCalledFunction() ||
        !NewObjCall->getCalledFunction()->getName().equals("CJ_MCC_NewObject") ||
        NewObjCall->getFunctionType() !=
            FunctionType::get(RefTy,
                              {Type::getInt8PtrTy(C), Type::getInt32Ty(C)},
                              false) ||
        !hasOrdinaryCallABI(NewObjCall))
      return false;
    if (ReturnsRef) {
      if (ThrowCI->getArgOperand(0) != CtorCall || !CtorCall->hasOneUse() ||
          !NewObjCall->hasOneUse())
        return false;
    } else if (ThrowCI->getArgOperand(0)->stripPointerCasts() != NewObjCall ||
               NewObjCall->getNumUses() != 2) {
      return false;
    }

    // Allocation and construction can read memory, throw or synchronize. Moving
    // either past another instruction is not justified by being in one block.
    // Only outline an adjacent sequence; debug records have no runtime effect.
    if (NewObjCall->getParent() != CtorCall->getParent() ||
        CtorCall->getParent() != ThrowCI->getParent() ||
        NewObjCall->getNextNonDebugInstruction() != CtorCall ||
        CtorCall->getNextNonDebugInstruction() != ThrowCI)
      return false;

    Value *TypeInfo = nullptr;
    Function *Helper = nullptr;
    SmallVector<Value *, 5> HelperArgs;
    IRBuilder<> IRB(ThrowCI);
    Value *CtorPtr = CtorCall->getCalledOperand();

    if (CtorCall->arg_size() == 2 &&
        isTypeInfoPtr(CtorCall->getArgOperand(1)->getType())) {
      TypeInfo = CtorCall->getArgOperand(1);
      // The helper accepts a pointer to this exact constructor type. Merely
      // matching argument count and the trailing TypeInfo does not establish
      // its return type or receiver type, even for ordinary C calls.
      if (CtorCall->getFunctionType() !=
          FunctionType::get(CtorCall->getType(),
                            {RefTy, TypeInfo->getType()}, false))
        return false;
      Helper =
          getOrInsertExceptionTailFunc(ExceptionTailHelperKind::Ctor0,
                                       cast<PointerType>(TypeInfo->getType()),
                                       nullptr, CtorCall->getType(),
                                       *ThrowCI->getFunction());
      HelperArgs = {NewObjCall->getArgOperand(0), NewObjCall->getArgOperand(1),
                    CtorPtr, TypeInfo};
    } else if (CtorCall->arg_size() == 3 &&
               isStdCoreStringPtr(CtorCall->getArgOperand(1)->getType()) &&
               isTypeInfoPtr(CtorCall->getArgOperand(2)->getType())) {
      TypeInfo = CtorCall->getArgOperand(2);
      if (CtorCall->getFunctionType() !=
          FunctionType::get(CtorCall->getType(),
                            {RefTy, CtorCall->getArgOperand(1)->getType(),
                             TypeInfo->getType()},
                            false))
        return false;
      Helper = getOrInsertExceptionTailFunc(
          ExceptionTailHelperKind::CtorString,
          cast<PointerType>(TypeInfo->getType()),
          CtorCall->getArgOperand(1)->getType(), CtorCall->getType(),
          *ThrowCI->getFunction());
      HelperArgs = {NewObjCall->getArgOperand(0), NewObjCall->getArgOperand(1),
                    CtorPtr, TypeInfo, CtorCall->getArgOperand(1)};
    } else {
      return false;
    }
    if (Helper == nullptr)
      return false;

    auto *HelperCall = IRB.CreateCall(Helper, HelperArgs);
    HelperCall->setDebugLoc(ThrowCI->getDebugLoc());
    HelperCall->setDoesNotReturn();

    Instruction *ThrownArgInst =
        dyn_cast<Instruction>(ThrowCI->getArgOperand(0));
    // Track the roots weakly: the same instruction can feed several arguments,
    // and deleting one root may recursively delete another. Raw pointers would
    // dangle in both cases. The roots are only candidates, so the cleanup below
    // must use the permissive variant that skips still-live entries.
    SmallVector<WeakTrackingVH, 4> DeadInstRoots;
    for (Value *Arg : NewObjCall->args()) {
      if (auto *Inst = dyn_cast<Instruction>(Arg))
        DeadInstRoots.push_back(Inst);
    }
    if (ThrownArgInst == CtorCall)
      ThrownArgInst = nullptr;
    ThrowCI->eraseFromParent();
    CtorCall->eraseFromParent();
    // Delete a now-dead throw-side cast chain before checking whether the
    // allocation itself can be dropped as well. This must stay ahead of the
    // use_empty() test below, otherwise the cast keeps NewObjCall alive.
    if (ThrownArgInst != nullptr && ThrownArgInst != NewObjCall)
      RecursivelyDeleteTriviallyDeadInstructions(ThrownArgInst);
    if (NewObjCall->use_empty())
      NewObjCall->eraseFromParent();
    RecursivelyDeleteTriviallyDeadInstructionsPermissive(DeadInstRoots);
    return true;
  }

  Module &M;
  LLVMContext &C;
};
} // namespace

PreservedAnalyses CJExceptionTailOutline::run(Module &M,
                                              ModuleAnalysisManager &AM) const {
  if (CJLTOOpt)
    return PreservedAnalyses::all();

  CJExceptionTailOutliner Outliner(M);
  bool Changed = false;
  for (Function &F : M) {
    // This one runs right after an implicit check failed, so it cannot afford
    // the extra frame an outlined tail adds. MergeFunctions' exception outline
    // skips it for the same reason, and outlining it here would silently
    // reintroduce the failure that guard exists to prevent. The stack overflow
    // entry point is not listed: the standard library stopped defining
    // `core.throwStackOverflowError`, so `rt$ThrowStackOverflowError` is no
    // longer emitted, and the overflow path goes through the runtime's
    // CJ_MCC_ThrowStackOverflowError instead.
    if (F.getName().equals("rt$ThrowImplicitException"))
      continue;
    Changed |= Outliner.extractExceptionTails(F);
  }

  if (!Changed)
    return PreservedAnalyses::all();

  PreservedAnalyses PA;
  PA.preserve<TargetLibraryAnalysis>();
  return PA;
}
