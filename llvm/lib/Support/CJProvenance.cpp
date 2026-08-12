//===- CJProvenance.cpp - Embed monorepo commit into LLVM tools -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Embeds "CJLLVM-COMMIT:<sha>[-dirty]" so a built opt/llc can answer which
// monorepo revision produced it:
//   strings <opt|llc> | grep -o 'CJLLVM-COMMIT:[0-9a-f-]*'
//
// Mirrors runtime g_cjRuntimeProvenance ("CJRT-COMMIT:") and cjc
// g_cjcjProvenance ("CJCJ-COMMIT:").  Bit-identical rebuilds are not required
// for that question; the stamp is.
//
//===----------------------------------------------------------------------===//

#ifndef CJ_LLVM_COMMIT
#define CJ_LLVM_COMMIT "unknown"
#endif

// Keep the symbol even under --gc-sections / strip of unreferenced globals.
extern "C" __attribute__((used, visibility("default")))
const char g_cjLLVMProvenance[] = "CJLLVM-COMMIT:" CJ_LLVM_COMMIT;
