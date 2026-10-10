//===- CJPartialEscapeAnalysisTest.cpp - PEA storage type regressions -------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/AsmParser/Parser.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Verifier.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/SourceMgr.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {
class CJPEAStorageTest : public testing::TestWithParam<bool> {
protected:
  LLVMContext Context;

  std::unique_ptr<Module> runPEA(StringRef IR) {
    Context.setOpaquePointers(GetParam());
    SMDiagnostic Error;
    auto M = parseAssemblyString(IR, Error, Context);
    if (!M) {
      Error.print("CJPEAStorageTest", errs());
      return nullptr;
    }
    if (verifyModule(*M, &errs()))
      return nullptr;
    LoopAnalysisManager LAM;
    FunctionAnalysisManager FAM;
    CGSCCAnalysisManager CGAM;
    ModuleAnalysisManager MAM;
    PassBuilder PB;
    PB.registerModuleAnalyses(MAM);
    PB.registerCGSCCAnalyses(CGAM);
    PB.registerFunctionAnalyses(FAM);
    PB.registerLoopAnalyses(LAM);
    PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);
    ModulePassManager PM;
    if (auto E = PB.parsePassPipeline(PM, "cj-pea")) {
      consumeError(std::move(E));
      return nullptr;
    }
    PM.run(*M, MAM);
    EXPECT_FALSE(verifyModule(*M, &errs()));
    return M;
  }

  void checkCopy(StringRef Source, bool Escapes) {
    std::string IR = R"(
      target datalayout = "e-p:64:64-p1:64:64"
      @gc = global [1 x i8 addrspace(1)*] zeroinitializer
      @plain = global [1 x i64] zeroinitializer
      @gc_alias = alias [1 x i8 addrspace(1)*], [1 x i8 addrspace(1)*]* @gc
      @plain_alias = alias [1 x i64], [1 x i64]* @plain
      @narrow_alias = alias i64, bitcast ([1 x i8 addrspace(1)*]* @gc to i64*)
      declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1 immarg)
      define void @copy(i8* %dst) {
        call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* )";
    IR += Source.str();
    IR += R"(, i64 8, i1 false)
        ret void
      }
    )";
    auto M = runPEA(IR);
    ASSERT_TRUE(M) << "valid input and registered product pass are prerequisites";
    uint64_t Info = M->getFunction("copy")->getArg(0)->getEscapeInfo();
    // Read the state produced by the complete product pass, rather than
    // querying a copy of its type classifier.
    errs() << "PEA_TARGET copy escape=" << Info << " expected=" << Escapes << '\n';
    EXPECT_EQ(Info != 0, Escapes);
  }

  void checkAllocation(StringRef Use, bool Retained) {
    std::string IR = R"(
      target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64"
      %TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
      %ObjLayout.Test = type { i64 }
      @ti = external global %TypeInfo, !RelatedType !0
      @slot = global i8 addrspace(1)* null
      @alias = alias i8 addrspace(1)*, i8 addrspace(1)** @slot
      @plain = global [1 x i64] zeroinitializer
      declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
      declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1 immarg)
      define void @allocate() gc "cangjie" {
        %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @ti to i8*), i32 16)
    )";
    IR += Use.str();
    IR += R"(
        ret void
      }
      !0 = !{!"ObjLayout.Test"}
    )";
    auto M = runPEA(IR);
    ASSERT_TRUE(M) << "valid layout and registered product pass are prerequisites";
    unsigned Allocations = 0;
    unsigned Allocas = 0;
    for (auto &BB : *M->getFunction("allocate"))
      for (auto &I : BB) {
        Allocas += isa<AllocaInst>(I);
        if (auto *CB = dyn_cast<CallBase>(&I))
          if (CB->getCalledFunction() &&
              CB->getCalledFunction()->getName() == "CJ_MCC_NewObject")
            ++Allocations;
      }
    errs() << "PEA_TARGET allocation retained=" << Allocations
           << " allocas=" << Allocas << " expected=" << Retained << '\n';
    EXPECT_EQ(Allocations, Retained ? 1u : 0u);
    EXPECT_EQ(Allocas, Retained ? 0u : 1u);
  }
};

TEST_P(CJPEAStorageTest, GlobalGC) {
  checkCopy("bitcast ([1 x i8 addrspace(1)*]* @gc to i8*)", true);
}
TEST_P(CJPEAStorageTest, GlobalNoGC) {
  checkCopy("bitcast ([1 x i64]* @plain to i8*)", false);
}
TEST_P(CJPEAStorageTest, AliasGC) {
  checkCopy("bitcast ([1 x i8 addrspace(1)*]* @gc_alias to i8*)", true);
}
TEST_P(CJPEAStorageTest, AliasNoGC) {
  checkCopy("bitcast ([1 x i64]* @plain_alias to i8*)", false);
}
TEST_P(CJPEAStorageTest, NarrowAliasGC) {
  checkCopy("bitcast (i64* @narrow_alias to i8*)", true);
}
TEST_P(CJPEAStorageTest, ConstantGEPGC) {
  checkCopy("bitcast (i8 addrspace(1)** getelementptr ([1 x i8 addrspace(1)*], [1 x i8 addrspace(1)*]* @gc, i64 0, i64 0) to i8*)", true);
}
TEST_P(CJPEAStorageTest, ConstantGEPNoGC) {
  checkCopy("bitcast (i64* getelementptr ([1 x i64], [1 x i64]* @plain, i64 0, i64 0) to i8*)", false);
}
TEST_P(CJPEAStorageTest, UnknownConstantAddress) {
  checkCopy("inttoptr (i64 4096 to i8*)", true);
}

TEST_P(CJPEAStorageTest, PublishedGlobalRetainsHeap) {
  checkAllocation("store i8 addrspace(1)* %obj, i8 addrspace(1)** @slot", true);
}
TEST_P(CJPEAStorageTest, PublishedAliasRetainsHeap) {
  checkAllocation("store i8 addrspace(1)* %obj, i8 addrspace(1)** @alias", true);
}
TEST_P(CJPEAStorageTest, NoGCSourceAllowsStack) {
  checkAllocation("call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %obj, i8* bitcast ([1 x i64]* @plain to i8*), i64 8, i1 false)", false);
}
TEST_P(CJPEAStorageTest, UnknownSourceRetainsHeap) {
  checkAllocation("call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %obj, i8* inttoptr (i64 4096 to i8*), i64 8, i1 false)", true);
}

INSTANTIATE_TEST_SUITE_P(PointerModes, CJPEAStorageTest,
                        testing::Values(false, true));
} // namespace
