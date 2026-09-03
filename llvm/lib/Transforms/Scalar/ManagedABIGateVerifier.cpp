//===- ManagedABIGateVerifier.cpp - Cangjie managed ABI gate -------------===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// Ordinary managed calls may exchange only PLAIN_SAFE references. Barrier
// intrinsics and the GC-private ABI are an explicit exception. This pass
// reports violations and values for which the current IR does not carry
// enough evidence; it never repairs, rejects, or rewrites a program.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Scalar/ManagedABIGateVerifier.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/SafepointIRVerifier.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

static cl::opt<bool> ManagedABIGateReportOnly(
    "managed-abi-gate-report-only", cl::init(false), cl::ReallyHidden,
    cl::desc("Report Cangjie managed ABI values without changing the IR"));

namespace {

static constexpr StringLiteral ColouredMarker = "cj.repr.coloured.v1";
static constexpr StringLiteral PlainSafeMarker = "cj.repr.plain_safe.v1";
static constexpr StringLiteral PlainUnsafeMarker = "cj.repr.plain_unsafe.v1";
static constexpr StringLiteral PlainSafeContract = "plain_safe";
static constexpr StringLiteral ArgContract = "cj.repr.arg";
static constexpr StringLiteral RetContract = "cj.repr.ret";
static constexpr StringLiteral SRetContract = "cj.repr.sret";

enum class RepresentationState {
  Coloured,
  PlainSafe,
  PlainUnsafe,
  Unknown,
};

struct StateInfo {
  RepresentationState State;
  const Value *Source;
};

enum class ReportReason {
  ColouredArgument,
  PlainUnsafeArgument,
  UnknownArgument,
  ColouredCallResult,
  PlainUnsafeCallResult,
  UnknownCallResult,
  ColouredReturn,
  PlainUnsafeReturn,
  UnknownReturn,
  ColouredNonHeapStore,
  PlainUnsafeNonHeapStore,
  UnknownNonHeapStore,
  SRetUnproven,
  Last,
};

struct GateCounters {
  uint64_t CallsSeen = 0;
  uint64_t CallsTotal = 0;
  uint64_t CallsPassed = 0;
  uint64_t CallsReported = 0;
  uint64_t CallsWhitelisted = 0;
  uint64_t CallsInlineAsmSkipped = 0;
  uint64_t ReturnsTotal = 0;
  uint64_t ReturnsPassed = 0;
  uint64_t ReturnsReported = 0;
  uint64_t NonHeapStoresTotal = 0;
  uint64_t NonHeapStoresPassed = 0;
  uint64_t NonHeapStoresReported = 0;
  uint64_t Reasons[static_cast<unsigned>(ReportReason::Last)] = {};
};

// This is intentionally an exact list. These names are the private runtime
// callees emitted by CJRuntimeLowering.cpp, CJBarrierLowering.cpp, and the
// frontend's CJNativeIntrinsicsCall.cpp/CGCommonDef.h tables. Prefix matching
// (for example, accepting every CJ_MCC_* symbol) would make additions invisible
// to review.
static constexpr StringLiteral PrivateRuntimeABI[] = {
    "CJ_LLVM_BlackHole",
    "CJ_MCC_AcquireRawData",
    "CJ_MCC_ApplyCJGenericInstanceMethod",
    "CJ_MCC_ApplyCJGenericStaticMethod",
    "CJ_MCC_ApplyCJInstanceMethod",
    "CJ_MCC_ApplyCJStaticMethod",
    "CJ_MCC_ArrayCopyGeneric",
    "CJ_MCC_ArrayCopyRef",
    "CJ_MCC_ArrayCopyStruct",
    "CJ_MCC_AssignGeneric",
    "CJ_MCC_AtomicCompareAndSwapReference",
    "CJ_MCC_AtomicReadReference",
    "CJ_MCC_AtomicSwapReference",
    "CJ_MCC_AtomicWriteReference",
    "CJ_MCC_AsanRead",
    "CJ_MCC_AsanWrite",
    "CJ_MCC_C2NStub",
    "CJ_MCC_CheckMethodActualArgs",
    "CJ_MCC_CopyStructField",
    "CJ_MCC_CreateExportHandle",
    "CJ_MCC_CrossAccessBarrier",
    "CJ_MCC_DecodeStackTrace",
    "CJ_MCC_DumpCJHeapData",
    "CJ_MCC_FillInStackTrace",
    "CJ_MCC_FutureInit",
    "CJ_MCC_FutureIsComplete",
    "CJ_MCC_FutureNotifyAll",
    "CJ_MCC_FutureWait",
    "CJ_MCC_GetAllocatedHeapSize",
    "CJ_MCC_GetAllThreadSnapshot",
    "CJ_MCC_GetBlockingCJThreadNumber",
    "CJ_MCC_GetCJThreadNumber",
    "CJ_MCC_GetCurrentCJThreadObject",
    "CJ_MCC_GetCurrentThreadSnapshot",
    "CJ_MCC_GetExceptionWrapper",
    "CJ_MCC_GetExportedRef",
    "CJ_MCC_GetGCCount",
    "CJ_MCC_GetGCFreedSize",
    "CJ_MCC_GetGCTimeUs",
    "CJ_MCC_GetJSLambdaAddr",
    "CJ_MCC_GetMTable",
    "CJ_MCC_GetMaxHeapSize",
    "CJ_MCC_GetMethodOuterTI",
    "CJ_MCC_GetNativeThreadNumber",
    "CJ_MCC_GetObjClass",
    "CJ_MCC_GetOrCreateTypeInfo",
    "CJ_MCC_GetOrCreateTypeInfoForReflect",
    "CJ_MCC_GetRealHeapSize",
    "CJ_MCC_HandleSafepoint",
    "CJ_MCC_InvokeGC",
    "CJ_MCC_IsSubType",
    "CJ_MCC_IsThreadObjectInited",
    "CJ_MCC_IsTupleTypeOf",
    "CJ_MCC_IsTypeInfoEqual",
    "CJ_MCC_IsWrapperClassForAutoEnv",
    "CJ_MCC_MonitorNotify",
    "CJ_MCC_MonitorNotifyAll",
    "CJ_MCC_MonitorWait",
    "CJ_MCC_MultiConditionMonitorNotify",
    "CJ_MCC_MultiConditionMonitorNotifyAll",
    "CJ_MCC_MultiConditionMonitorWait",
    "CJ_MCC_MutexCheckStatus",
    "CJ_MCC_MutexInit",
    "CJ_MCC_MutexLock",
    "CJ_MCC_MutexTryLock",
    "CJ_MCC_MutexUnlock",
    "CJ_MCC_N2CStub",
    "CJ_MCC_NewAndInitEnumTupleObject",
    "CJ_MCC_NewArray",
    "CJ_MCC_NewArray16",
    "CJ_MCC_NewArray32",
    "CJ_MCC_NewArray64",
    "CJ_MCC_NewArray8",
    "CJ_MCC_NewArrayGeneric",
    "CJ_MCC_NewFinalizer",
    "CJ_MCC_NewFinalizerFast",
    "CJ_MCC_NewObjArray",
    "CJ_MCC_NewObject",
    "CJ_MCC_NewObjectFast",
    "CJ_MCC_NewPinnedObject",
    "CJ_MCC_NewWeakRefObject",
    "CJ_MCC_OnFinalizerCreated",
    "CJ_MCC_PostThrowException",
    "CJ_MCC_ReadGeneric",
    "CJ_MCC_ReadRefField",
    "CJ_MCC_ReadStaticRef",
    "CJ_MCC_ReadStaticStruct",
    "CJ_MCC_ReadStructField",
    "CJ_MCC_ReadWeakRef",
    "CJ_MCC_RegisterImplicitExceptionRaisers",
    "CJ_MCC_ReleaseRawData",
    "CJ_MCC_RemoveExportedRef",
    "CJ_MCC_SetCurrentCJThreadObject",
    "CJ_MCC_SetGCThreshold",
    "CJ_MCC_StackCheck",
    "CJ_MCC_StartCpuProfiling",
    "CJ_MCC_StopCpuProfiling",
    "CJ_MCC_ThrowArithmeticException",
    "CJ_MCC_ThrowException",
    "CJ_MCC_UpdateVMT",
    "CJ_MCC_WaitQueueForMonitorInit",
    "CJ_MCC_WaitQueueInit",
    "CJ_MCC_WriteGeneric",
    "CJ_MCC_WriteGenericPayload",
    "CJ_MCC_WriteRefField",
    "CJ_MCC_WriteStaticRef",
    "CJ_MCC_WriteStaticStruct",
    "CJ_MCC_WriteStructField",
    "CJ_MC_CGetExceptionTypeID",
    "CJ_MRT_PreInitializePackage",
    "CJ_MRT_Sleep",
    "CJ_Safepoint_Stub",
    "GetCJThreadIdForMutexOpt",
    "SetDebugLocation",
};

static StringRef stateName(RepresentationState State) {
  switch (State) {
  case RepresentationState::Coloured:
    return "COLOURED";
  case RepresentationState::PlainSafe:
    return "PLAIN_SAFE";
  case RepresentationState::PlainUnsafe:
    return "PLAIN_UNSAFE";
  case RepresentationState::Unknown:
    return "UNKNOWN";
  }
  llvm_unreachable("unknown representation state");
}

static StringRef reasonName(ReportReason Reason) {
  switch (Reason) {
  case ReportReason::ColouredArgument:
    return "COLOURED_ARGUMENT";
  case ReportReason::PlainUnsafeArgument:
    return "PLAIN_UNSAFE_ARGUMENT";
  case ReportReason::UnknownArgument:
    return "UNKNOWN_ARGUMENT";
  case ReportReason::ColouredCallResult:
    return "COLOURED_CALL_RESULT";
  case ReportReason::PlainUnsafeCallResult:
    return "PLAIN_UNSAFE_CALL_RESULT";
  case ReportReason::UnknownCallResult:
    return "UNKNOWN_CALL_RESULT";
  case ReportReason::ColouredReturn:
    return "COLOURED_RETURN";
  case ReportReason::PlainUnsafeReturn:
    return "PLAIN_UNSAFE_RETURN";
  case ReportReason::UnknownReturn:
    return "UNKNOWN_RETURN";
  case ReportReason::ColouredNonHeapStore:
    return "COLOURED_NONHEAP_STORE";
  case ReportReason::PlainUnsafeNonHeapStore:
    return "PLAIN_UNSAFE_NONHEAP_STORE";
  case ReportReason::UnknownNonHeapStore:
    return "UNKNOWN_NONHEAP_STORE";
  case ReportReason::SRetUnproven:
    return "SRET_UNPROVEN";
  case ReportReason::Last:
    break;
  }
  llvm_unreachable("unknown report reason");
}

static const Function *getDirectCallee(const CallBase &CB) {
  return dyn_cast<Function>(CB.getCalledOperand()->stripPointerCasts());
}

static bool isCangjiePrivateIntrinsic(Intrinsic::ID ID) {
  switch (ID) {
  case Intrinsic::cj_gcwrite_ref:
  case Intrinsic::cj_gcwrite_struct:
  case Intrinsic::cj_gcwrite_static_ref:
  case Intrinsic::cj_gcwrite_static_struct:
  case Intrinsic::cj_gcread_ref:
  case Intrinsic::cj_gcread_weakref:
  case Intrinsic::cj_gcread_struct:
  case Intrinsic::cj_gcread_static_ref:
  case Intrinsic::cj_gcread_static_struct:
  case Intrinsic::cj_copy_no_ref_struct:
  case Intrinsic::cj_array_copy_ref:
  case Intrinsic::cj_array_copy_struct:
  case Intrinsic::cj_copy_struct_field:
  case Intrinsic::cj_cross_access_barrier:
  case Intrinsic::cj_get_exported_ref:
  case Intrinsic::cj_remove_exported_ref:
  case Intrinsic::cj_create_export_handle:
  case Intrinsic::cj_get_lambda_addr:
  case Intrinsic::cj_get_obj_klass:
  case Intrinsic::cj_memset:
  case Intrinsic::cj_malloc_object:
  case Intrinsic::cj_malloc_array:
  case Intrinsic::cj_division_check_sdiv:
  case Intrinsic::cj_division_check_udiv:
  case Intrinsic::cj_division_check_srem:
  case Intrinsic::cj_division_check_urem:
  case Intrinsic::cj_acquire_rawdata:
  case Intrinsic::cj_release_rawdata:
  case Intrinsic::cj_post_throw_exception:
  case Intrinsic::cj_throw_exception:
  case Intrinsic::cj_get_exception_wrapper:
  case Intrinsic::cj_get_exception_typeid:
  case Intrinsic::cj_pre_initialize_package:
  case Intrinsic::cj_fill_in_stack_trace:
  case Intrinsic::cj_get_real_heap_size:
  case Intrinsic::cj_get_allocated_heap_size:
  case Intrinsic::cj_get_max_heap_size:
  case Intrinsic::cj_dump_heap_data:
  case Intrinsic::cj_get_thread_number:
  case Intrinsic::cj_get_blocking_thread_number:
  case Intrinsic::cj_get_native_thread_number:
  case Intrinsic::cj_get_gc_count:
  case Intrinsic::cj_get_gc_time_us:
  case Intrinsic::cj_get_gc_freed_size:
  case Intrinsic::cj_start_cpu_profiling:
  case Intrinsic::cj_stop_cpu_profiling:
  case Intrinsic::cj_set_gc_threshold:
  case Intrinsic::cj_invoke_gc:
  case Intrinsic::cj_register_implicit_exception_raisers:
  case Intrinsic::cj_atomic_store:
  case Intrinsic::cj_atomic_load:
  case Intrinsic::cj_atomic_swap:
  case Intrinsic::cj_atomic_compare_swap:
  case Intrinsic::cj_get_fp_state:
  case Intrinsic::cj_reset_fp_state:
  case Intrinsic::cj_set_location:
  case Intrinsic::cj_blackhole:
  case Intrinsic::cj_get_type_info:
  case Intrinsic::cj_get_field_offset:
  case Intrinsic::cj_is_subtype:
  case Intrinsic::cj_is_tupletype_of:
  case Intrinsic::cj_is_typeinfo_equal:
  case Intrinsic::cj_is_reference:
  case Intrinsic::cj_alloca_generic:
  case Intrinsic::cj_gcwrite_generic:
  case Intrinsic::cj_gcread_generic:
  case Intrinsic::cj_get_mtable_func:
  case Intrinsic::cj_get_method_outertype:
  case Intrinsic::cj_get_vtable_func:
  case Intrinsic::cj_vfe_info:
  case Intrinsic::cj_assign_generic:
  case Intrinsic::cj_malloc_array_generic:
  case Intrinsic::cj_array_copy_generic:
  case Intrinsic::cj_gcwrite_generic_payload:
  case Intrinsic::cj_gcread_generic_payload:
  case Intrinsic::cj_gc_statepoint:
  case Intrinsic::cj_gc_result:
  case Intrinsic::cj_gc_relocate:
  case Intrinsic::cj_stack_relocate:
    return true;
  default:
    return false;
  }
}

static bool isPrivateABICall(const CallBase &CB) {
  Intrinsic::ID ID = CB.getIntrinsicID();
  if (isCangjiePrivateIntrinsic(ID))
    return true;
  // Non-Cangjie LLVM intrinsics are compiler operations, not managed calls.
  if (ID != Intrinsic::not_intrinsic)
    return true;
  const Function *Callee = getDirectCallee(CB);
  return Callee && is_contained(PrivateRuntimeABI, Callee->getName());
}

static bool isKnownPlainProducer(const CallBase &CB) {
  switch (CB.getIntrinsicID()) {
  case Intrinsic::cj_gcread_ref:
  case Intrinsic::cj_gcread_weakref:
  case Intrinsic::cj_gcread_static_ref:
  case Intrinsic::cj_malloc_object:
  case Intrinsic::cj_malloc_array:
  case Intrinsic::cj_alloca_generic:
  case Intrinsic::cj_malloc_array_generic:
  case Intrinsic::cj_atomic_load:
  case Intrinsic::cj_atomic_swap:
  case Intrinsic::cj_gc_relocate:
    return true;
  default:
    break;
  }
  const Function *Callee = getDirectCallee(CB);
  if (!Callee)
    return false;
  StringRef Name = Callee->getName();
  return Name == "CJ_MCC_ReadRefField" || Name == "CJ_MCC_ReadWeakRef" ||
         Name == "CJ_MCC_ReadStaticRef" ||
         Name == "CJ_MCC_AtomicReadReference" ||
         Name == "CJ_MCC_AtomicSwapReference" || Name == "CJ_MCC_NewArray" ||
         Name == "CJ_MCC_NewArray8" || Name == "CJ_MCC_NewArray16" ||
         Name == "CJ_MCC_NewArray32" || Name == "CJ_MCC_NewArray64" ||
         Name == "CJ_MCC_NewArrayGeneric" || Name == "CJ_MCC_NewFinalizer" ||
         Name == "CJ_MCC_NewFinalizerFast" || Name == "CJ_MCC_NewObjArray" ||
         Name == "CJ_MCC_NewObject" || Name == "CJ_MCC_NewObjectFast" ||
         Name == "CJ_MCC_NewPinnedObject" ||
         Name == "CJ_MCC_NewWeakRefObject" ||
         Name == "CJ_MCC_GetExportedRef";
}

static Optional<RepresentationState>
getRepresentationMarkerState(const CallBase &CB) {
  if (CB.getIntrinsicID() != Intrinsic::ptr_annotation || CB.arg_size() < 2)
    return None;
  StringRef Annotation;
  if (!getConstantStringInfo(CB.getArgOperand(1), Annotation))
    return None;
  if (Annotation == ColouredMarker)
    return RepresentationState::Coloured;
  if (Annotation == PlainSafeMarker)
    return RepresentationState::PlainSafe;
  if (Annotation == PlainUnsafeMarker)
    return RepresentationState::PlainUnsafe;
  return None;
}

static bool hasPlainSafeAttribute(Attribute Attr) {
  return Attr.isValid() && Attr.isStringAttribute() &&
         Attr.getValueAsString() == PlainSafeContract;
}

static bool hasPlainSafeRetContract(const CallBase &CB) {
  return hasPlainSafeAttribute(CB.getAttributeAtIndex(
      AttributeList::ReturnIndex, RetContract));
}

static bool hasPlainSafeArgContract(const CallBase &CB, unsigned ArgNo) {
  return hasPlainSafeAttribute(CB.getParamAttr(ArgNo, ArgContract));
}

static bool hasPlainSafeSRetContract(const CallBase &CB, unsigned ArgNo) {
  return hasPlainSafeAttribute(CB.getParamAttr(ArgNo, SRetContract));
}

static StateInfo mergeStates(StateInfo A, StateInfo B) {
  if (A.State == B.State)
    return A;
  if (A.State == RepresentationState::Coloured)
    return A;
  if (B.State == RepresentationState::Coloured)
    return B;
  if (A.State == RepresentationState::PlainUnsafe)
    return A;
  if (B.State == RepresentationState::PlainUnsafe)
    return B;
  if (A.State == RepresentationState::Unknown)
    return A;
  return B;
}

class StateClassifier {
  DenseMap<const Value *, StateInfo> Cache;
  SmallPtrSet<const Value *, 32> Active;

  StateInfo classifyImpl(const Value *V) {
    if (isa<ConstantPointerNull>(V) || isa<ConstantAggregateZero>(V))
      return {RepresentationState::PlainSafe, V};
    if (isa<Argument>(V))
      return {RepresentationState::PlainSafe, V};

    if (const auto *CB = dyn_cast<CallBase>(V)) {
      if (Optional<RepresentationState> Marker =
              getRepresentationMarkerState(*CB)) {
        StateInfo Operand = classify(CB->getArgOperand(0));
        if (Operand.State == RepresentationState::Coloured ||
            Operand.State == RepresentationState::PlainUnsafe)
          return Operand;
        return {*Marker, V};
      }
      if (isKnownPlainProducer(*CB))
        return {RepresentationState::PlainSafe, V};
      if (hasPlainSafeRetContract(*CB))
        return {RepresentationState::PlainSafe, V};
      const Function *Callee = getDirectCallee(*CB);
      if (Callee && Callee->hasCangjieGC() && !Callee->isDeclaration() &&
          !isPrivateABICall(*CB) && !Callee->hasFnAttribute("cj2c") &&
          !Callee->hasFnAttribute("c2cj")) {
        StateInfo Result{RepresentationState::PlainSafe, V};
        bool HasManagedReturn = false;
        for (const Instruction &I : instructions(*Callee)) {
          const auto *RI = dyn_cast<ReturnInst>(&I);
          if (!RI || !RI->getReturnValue())
            continue;
          HasManagedReturn = true;
          Result = mergeStates(Result, classify(RI->getReturnValue()));
        }
        if (HasManagedReturn)
          return Result;
      }
      return {RepresentationState::Unknown, V};
    }

    if (const auto *LI = dyn_cast<LoadInst>(V)) {
      if (LI->getPointerAddressSpace() == 1)
        return {RepresentationState::Coloured, V};
      return {RepresentationState::Unknown, V};
    }

    if (const auto *II = dyn_cast<IntrinsicInst>(V))
      if (II->getIntrinsicID() == Intrinsic::ptrmask)
        return {RepresentationState::PlainUnsafe, V};

    if (const auto *I2P = dyn_cast<IntToPtrInst>(V)) {
      if (isa<BinaryOperator>(I2P->getOperand(0)))
        return {RepresentationState::PlainUnsafe, V};
      return {RepresentationState::Unknown, V};
    }

    if (const auto *CI = dyn_cast<CastInst>(V)) {
      StateInfo Operand = classify(CI->getOperand(0));
      if (isa<AddrSpaceCastInst>(CI) &&
          !isGCPointerType(CI->getOperand(0)->getType()))
        return {RepresentationState::Unknown, V};
      return Operand;
    }

    if (const auto *GEP = dyn_cast<GetElementPtrInst>(V))
      return classify(GEP->getPointerOperand());
    if (const auto *FI = dyn_cast<FreezeInst>(V))
      return classify(FI->getOperand(0));

    if (const auto *SI = dyn_cast<SelectInst>(V))
      return mergeStates(classify(SI->getTrueValue()),
                         classify(SI->getFalseValue()));

    if (const auto *PN = dyn_cast<PHINode>(V)) {
      StateInfo Result{RepresentationState::PlainSafe, V};
      for (const Value *Incoming : PN->incoming_values())
        Result = mergeStates(Result, classify(Incoming));
      return Result;
    }

    if (const auto *IV = dyn_cast<InsertValueInst>(V))
      return mergeStates(classify(IV->getAggregateOperand()),
                         classify(IV->getInsertedValueOperand()));
    if (const auto *EV = dyn_cast<ExtractValueInst>(V))
      return classify(EV->getAggregateOperand());

    return {RepresentationState::Unknown, V};
  }

public:
  StateInfo classify(const Value *V) {
    auto Cached = Cache.find(V);
    if (Cached != Cache.end())
      return Cached->second;
    if (!Active.insert(V).second)
      return {RepresentationState::Unknown, V};
    StateInfo Result = classifyImpl(V);
    Active.erase(V);
    Cache.insert({V, Result});
    return Result;
  }
};

static ReportReason argumentReason(RepresentationState State) {
  switch (State) {
  case RepresentationState::Coloured:
    return ReportReason::ColouredArgument;
  case RepresentationState::PlainUnsafe:
    return ReportReason::PlainUnsafeArgument;
  case RepresentationState::Unknown:
    return ReportReason::UnknownArgument;
  case RepresentationState::PlainSafe:
    break;
  }
  llvm_unreachable("PLAIN_SAFE is not a report reason");
}

static ReportReason callResultReason(RepresentationState State) {
  switch (State) {
  case RepresentationState::Coloured:
    return ReportReason::ColouredCallResult;
  case RepresentationState::PlainUnsafe:
    return ReportReason::PlainUnsafeCallResult;
  case RepresentationState::Unknown:
    return ReportReason::UnknownCallResult;
  case RepresentationState::PlainSafe:
    break;
  }
  llvm_unreachable("PLAIN_SAFE is not a report reason");
}

static ReportReason returnReason(RepresentationState State) {
  switch (State) {
  case RepresentationState::Coloured:
    return ReportReason::ColouredReturn;
  case RepresentationState::PlainUnsafe:
    return ReportReason::PlainUnsafeReturn;
  case RepresentationState::Unknown:
    return ReportReason::UnknownReturn;
  case RepresentationState::PlainSafe:
    break;
  }
  llvm_unreachable("PLAIN_SAFE is not a report reason");
}

static ReportReason nonHeapStoreReason(RepresentationState State) {
  switch (State) {
  case RepresentationState::Coloured:
    return ReportReason::ColouredNonHeapStore;
  case RepresentationState::PlainUnsafe:
    return ReportReason::PlainUnsafeNonHeapStore;
  case RepresentationState::Unknown:
    return ReportReason::UnknownNonHeapStore;
  case RepresentationState::PlainSafe:
    break;
  }
  llvm_unreachable("PLAIN_SAFE is not a report reason");
}

class ManagedABIGateVerifier {
  Module &M;
  GateCounters Counters;
  StateClassifier Classifier;

  void report(ReportReason Reason, const Function &F, StringRef Callee,
              unsigned Index, StateInfo Info) {
    ++Counters.Reasons[static_cast<unsigned>(Reason)];
    errs() << "[MANAGED_ABI_GATE] report reason=" << reasonName(Reason)
           << " function=" << F.getName();
    if (!Callee.empty())
      errs() << " callee=" << Callee;
    errs() << " index=" << Index << " state=" << stateName(Info.State);
    if (const auto *I = dyn_cast_or_null<Instruction>(Info.Source))
      errs() << " source_opcode=" << I->getOpcodeName();
    errs() << " source=";
    if (Info.Source)
      Info.Source->printAsOperand(errs(), false);
    else
      errs() << "<none>";
    errs() << '\n';
  }

  void verifyCall(const CallBase &CB) {
    ++Counters.CallsSeen;
    if (isPrivateABICall(CB)) {
      ++Counters.CallsWhitelisted;
      return;
    }
    if (CB.isInlineAsm()) {
      ++Counters.CallsInlineAsmSkipped;
      return;
    }

    ++Counters.CallsTotal;
    bool Reported = false;
    const Function *Callee = getDirectCallee(CB);
    StringRef CalleeName = Callee ? Callee->getName() : StringRef("<indirect>");

    for (unsigned I = 0; I < CB.arg_size(); ++I) {
      if (CB.paramHasAttr(I, Attribute::StructRet)) {
        Type *SRetTy = CB.getParamStructRetType(I);
        if (SRetTy && containsGCPtrType(SRetTy) &&
            !hasPlainSafeSRetContract(CB, I)) {
          StateInfo Info{RepresentationState::Unknown, CB.getArgOperand(I)};
          report(ReportReason::SRetUnproven, *CB.getFunction(), CalleeName, I,
                 Info);
          Reported = true;
        }
      }

      Value *Arg = CB.getArgOperand(I);
      if (!containsGCPtrType(Arg->getType()))
        continue;
      StateInfo Info = Classifier.classify(Arg);
      if (Info.State == RepresentationState::Unknown &&
          hasPlainSafeArgContract(CB, I))
        continue;
      if (Info.State == RepresentationState::PlainSafe)
        continue;
      report(argumentReason(Info.State), *CB.getFunction(), CalleeName, I,
             Info);
      Reported = true;
    }

    if (containsGCPtrType(CB.getType())) {
      StateInfo Info = Classifier.classify(&CB);
      if (Info.State != RepresentationState::PlainSafe) {
        report(callResultReason(Info.State), *CB.getFunction(), CalleeName, 0,
               Info);
        Reported = true;
      }
    }

    if (Reported)
      ++Counters.CallsReported;
    else
      ++Counters.CallsPassed;
  }

  void verifyReturn(const ReturnInst &RI) {
    const Value *Value = RI.getReturnValue();
    if (!Value || !containsGCPtrType(Value->getType()))
      return;
    ++Counters.ReturnsTotal;
    StateInfo Info = Classifier.classify(Value);
    if (Info.State == RepresentationState::PlainSafe) {
      ++Counters.ReturnsPassed;
      return;
    }
    report(returnReason(Info.State), *RI.getFunction(), "", 0, Info);
    ++Counters.ReturnsReported;
  }

  void verifyNonHeapStore(const StoreInst &SI) {
    if (SI.getPointerAddressSpace() == 1 ||
        !containsGCPtrType(SI.getValueOperand()->getType()))
      return;
    ++Counters.NonHeapStoresTotal;
    StateInfo Info = Classifier.classify(SI.getValueOperand());
    if (Info.State == RepresentationState::PlainSafe) {
      ++Counters.NonHeapStoresPassed;
      return;
    }
    report(nonHeapStoreReason(Info.State), *SI.getFunction(), "", 0, Info);
    ++Counters.NonHeapStoresReported;
  }

public:
  explicit ManagedABIGateVerifier(Module &M) : M(M) {}

  void run() {
    for (Function &F : M) {
      if (!F.hasCangjieGC())
        continue;
      for (Instruction &I : instructions(F)) {
        if (const auto *CB = dyn_cast<CallBase>(&I)) {
          if (isa<CallInst>(CB) || isa<InvokeInst>(CB))
            verifyCall(*CB);
        }
        if (const auto *RI = dyn_cast<ReturnInst>(&I))
          verifyReturn(*RI);
        if (const auto *SI = dyn_cast<StoreInst>(&I))
          verifyNonHeapStore(*SI);
      }
    }

    errs() << "[MANAGED_ABI_GATE] summary module=" << M.getName()
           << " calls_total=" << Counters.CallsTotal
           << " calls_passed=" << Counters.CallsPassed
           << " calls_reported=" << Counters.CallsReported
           << " returns_total=" << Counters.ReturnsTotal
           << " returns_passed=" << Counters.ReturnsPassed
           << " returns_reported=" << Counters.ReturnsReported
           << " nonheap_stores_total=" << Counters.NonHeapStoresTotal
           << " nonheap_stores_passed=" << Counters.NonHeapStoresPassed
           << " nonheap_stores_reported=" << Counters.NonHeapStoresReported
           << " calls_seen=" << Counters.CallsSeen
           << " calls_whitelisted=" << Counters.CallsWhitelisted
           << " calls_inlineasm_skipped=" << Counters.CallsInlineAsmSkipped;
    for (unsigned I = 0; I < static_cast<unsigned>(ReportReason::Last); ++I)
      errs() << " reason_"
             << reasonName(static_cast<ReportReason>(I)).lower() << '='
             << Counters.Reasons[I];
    errs() << '\n';
  }
};

} // namespace

PreservedAnalyses
ManagedABIGateVerifierPass::run(Module &M, ModuleAnalysisManager &) const {
  if (ManagedABIGateReportOnly)
    ManagedABIGateVerifier(M).run();
  return PreservedAnalyses::all();
}
