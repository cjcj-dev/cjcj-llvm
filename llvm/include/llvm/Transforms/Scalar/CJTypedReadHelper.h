//===- CJTypedReadHelper.h - typed aggregate read rewrite -------*- C++ -*-===//

#ifndef LLVM_TRANSFORMS_SCALAR_CJ_TYPED_READ_HELPER_H
#define LLVM_TRANSFORMS_SCALAR_CJ_TYPED_READ_HELPER_H

#include "llvm/IR/PassManager.h"

namespace llvm {

class Module;

/// Rewrite a proven AS1 aggregate read into llvm.cj.gcread.struct.
///
/// The pass is deliberately fail-closed: only complete, constant-size
/// payloads with an entry-block AS0 alloca destination and a recoverable
/// managed-object base are transformed.
struct CJTypedReadHelper : public PassInfoMixin<CJTypedReadHelper> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) const;
};

} // namespace llvm

#endif // LLVM_TRANSFORMS_SCALAR_CJ_TYPED_READ_HELPER_H
