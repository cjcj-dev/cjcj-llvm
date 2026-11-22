//===-- WebAssemblyCJLowerLandingPads.cpp - Cangjie wasm EH funclets ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Cangjie wasm32-wasi exception handling (M1). Cangjie emits Itanium-style
/// invoke/landingpad/resume IR with a `token` landingpad and fetches the
/// in-flight exception through CJ_MCC_GetExceptionWrapper /
/// CJ_MCC_PostThrowException. The wasm EH backend only understands funclet
/// pads, so before WasmEHPrepare every landingpad block becomes
///
///   lpad:  catchswitch within none [label %lpad.cj.catch] unwind to caller
///   lpad.cj.catch: %cp = catchpad within %cs [ptr null]   ; catch_all
///                  catchret from %cp to label %lpad.cj.body
///   lpad.cj.body:  <original handler code>
///
/// The handler body runs outside the funclet, so nested invokes keep unwinding
/// to their own pads. The runtime throws with the single C++ tag (index 0), and
/// catch_all catches it without a personality call. `resume` becomes a call to
/// CJ_MCC_WasmRethrow, which throws the in-flight exception again.
///
//===----------------------------------------------------------------------===//

#include "WebAssembly.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Transforms/Utils/Local.h"
using namespace llvm;

#define DEBUG_TYPE "wasm-cj-lower-landingpads"

namespace {
class WebAssemblyCJLowerLandingPads final : public FunctionPass {
public:
  static char ID;
  WebAssemblyCJLowerLandingPads() : FunctionPass(ID) {}
  StringRef getPassName() const override {
    return "WebAssembly Cangjie landingpad to catch_all funclet lowering";
  }
  bool runOnFunction(Function &F) override;
};
} // end anonymous namespace

char WebAssemblyCJLowerLandingPads::ID = 0;
INITIALIZE_PASS(WebAssemblyCJLowerLandingPads, DEBUG_TYPE,
                "Lower Cangjie landingpads to wasm catch_all funclets", false,
                false)

FunctionPass *llvm::createWebAssemblyCJLowerLandingPads() {
  return new WebAssemblyCJLowerLandingPads();
}

static bool isCangjieFunction(const Function &F) {
  return F.hasGC() && F.getGC() == "cangjie";
}

bool WebAssemblyCJLowerLandingPads::runOnFunction(Function &F) {
  // Only Cangjie functions get catch_all funclets. Foreign landingpads, such as
  // a C++ __gxx_personality_v0 {i8*, i32} pad, keep their selector here.
  if (!isCangjieFunction(F))
    return false;
  if (!F.hasPersonalityFn())
    return false;
  SmallVector<LandingPadInst *, 8> Pads;
  SmallVector<ResumeInst *, 8> Resumes;
  for (BasicBlock &BB : F) {
    if (LandingPadInst *LP = BB.getLandingPadInst())
      Pads.push_back(LP);
    if (auto *R = dyn_cast<ResumeInst>(BB.getTerminator()))
      Resumes.push_back(R);
  }
  if (Pads.empty() && Resumes.empty())
    return false;
  Module &M = *F.getParent();
  LLVMContext &C = M.getContext();

  FunctionCallee Rethrow = M.getOrInsertFunction(
      "CJ_MCC_WasmRethrow", FunctionType::get(Type::getVoidTy(C), false));
  if (auto *RF = dyn_cast<Function>(Rethrow.getCallee()))
    RF->setDoesNotReturn();
  for (ResumeInst *R : Resumes) {
    CallInst *CI = CallInst::Create(Rethrow, "", R);
    CI->setDoesNotReturn();
    CI->setDebugLoc(R->getDebugLoc());
    new UnreachableInst(C, R);
    R->eraseFromParent();
  }

  for (LandingPadInst *LP : Pads) {
    BasicBlock *BB = LP->getParent();
    // A catchswitch block keeps only its pad; PHIs move to memory. The reload
    // lands after the landingpad and so in the handler body below.
    SmallVector<PHINode *, 4> Phis;
    for (PHINode &PN : BB->phis())
      Phis.push_back(&PN);
    for (PHINode *PN : Phis)
      DemotePHIToStack(PN);
    BasicBlock *Body =
        BB->splitBasicBlock(LP->getNextNode(), BB->getName() + ".cj.body");
    if (!LP->use_empty())
      LP->replaceAllUsesWith(UndefValue::get(LP->getType()));
    BB->getTerminator()->eraseFromParent();
    LP->eraseFromParent();
    BasicBlock *Catch =
        BasicBlock::Create(C, BB->getName() + ".cj.catch", &F, Body);
    auto *CS = CatchSwitchInst::Create(ConstantTokenNone::get(C), nullptr, 1,
                                       "cj.cs", BB);
    CS->addHandler(Catch);
    auto *CP = CatchPadInst::Create(
        CS, {Constant::getNullValue(Type::getInt8PtrTy(C))}, "cj.cp", Catch);
    CatchReturnInst::Create(CP, Body, Catch);
  }

  // Wasm_CXX classification drives WasmEHFuncInfo and the wasm unwind
  // destinations; catch_all pads never call the personality.
  FunctionCallee Pers = M.getOrInsertFunction(
      "__gxx_wasm_personality_v0",
      FunctionType::get(Type::getInt32Ty(C), true));
  F.setPersonalityFn(cast<Constant>(Pers.getCallee()));
  return true;
}

namespace {
/// Wasm EH is on for the whole module on wasm32-wasi, but only Cangjie pads are
/// turned into funclets. A non-Cangjie invoke becomes a plain call, which is
/// what LowerInvoke did for every function before wasm EH, so its landingpad is
/// unreachable and never reaches WasmEHPrepare as a catch_all pad.
class WebAssemblyCJLowerForeignInvokes final : public FunctionPass {
public:
  static char ID;
  WebAssemblyCJLowerForeignInvokes() : FunctionPass(ID) {}
  StringRef getPassName() const override {
    return "WebAssembly lower non-Cangjie invokes under Cangjie wasm EH";
  }
  bool runOnFunction(Function &F) override {
    if (isCangjieFunction(F))
      return false;
    SmallVector<InvokeInst *, 8> Invokes;
    for (BasicBlock &BB : F)
      if (auto *II = dyn_cast<InvokeInst>(BB.getTerminator()))
        Invokes.push_back(II);
    for (InvokeInst *II : Invokes)
      changeToCall(II);
    return !Invokes.empty();
  }
};
} // end anonymous namespace

char WebAssemblyCJLowerForeignInvokes::ID = 0;
INITIALIZE_PASS(WebAssemblyCJLowerForeignInvokes, "wasm-cj-lower-foreign-invokes",
                "Lower non-Cangjie invokes under Cangjie wasm EH", false, false)

FunctionPass *llvm::createWebAssemblyCJLowerForeignInvokes() {
  return new WebAssemblyCJLowerForeignInvokes();
}
