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
TEST_P(CJPEAStorageTest, ConstantGEPGC) {
  checkCopy("bitcast (i8 addrspace(1)** getelementptr ([1 x i8 addrspace(1)*], [1 x i8 addrspace(1)*]* @gc, i64 0, i64 0) to i8*)", true);
}
TEST_P(CJPEAStorageTest, ConstantGEPNoGC) {
  checkCopy("bitcast (i64* getelementptr ([1 x i64], [1 x i64]* @plain, i64 0, i64 0) to i8*)", false);
}
TEST_P(CJPEAStorageTest, UnknownConstantAddress) {
  checkCopy("inttoptr (i64 4096 to i8*)", true);
}

INSTANTIATE_TEST_SUITE_P(PointerModes, CJPEAStorageTest,
                        testing::Values(false, true));
} // namespace
