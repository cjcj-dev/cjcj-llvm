//===- cjir-capture.cpp - Capture CJIR memtransfer proof inputs ----------===//
//
// This tool records the inputs and intermediate values used by the CJIR
// verifier's bare-memtransfer predicates.  In particular, reference
// classification calls the product containsGCPtrType helper; it is not
// reimplemented here.
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/APInt.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/IR/SafepointIRVerifier.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Scalar/CJFillMetadata.h"

#include <algorithm>
#include <cstdint>
#include <limits>
#include <string>

using namespace llvm;

namespace {

cl::opt<std::string> InputFilename(cl::Positional, cl::desc("<input IR/BC>"),
                                   cl::Required);
cl::opt<std::string> ModuleName("module-name", cl::desc("Stable module key"),
                                cl::value_desc("name"), cl::Required);

std::string typeIR(Type *Ty) {
  std::string S;
  raw_string_ostream OS(S);
  Ty->print(OS);
  return OS.str();
}

std::string valueIR(Value *V) {
  std::string S;
  raw_string_ostream OS(S);
  V->printAsOperand(OS, true);
  return OS.str();
}

std::string instructionIR(Instruction &I) {
  std::string S;
  raw_string_ostream OS(S);
  I.print(OS);
  return OS.str();
}

std::string unsignedString(uint64_t V) { return std::to_string(V); }

std::string unsignedString(const APInt &V) {
  SmallString<32> Buffer;
  V.toStringUnsigned(Buffer);
  return Buffer.str().str();
}

json::Value unrecoverable(StringRef Reason) {
  return json::Object{{"status", "unrecoverable"},
                      {"reason", Reason.str()}};
}

json::Object operandCapture(Value *V) {
  json::Object O{{"ir", valueIR(V)}};
  if (auto *CI = dyn_cast<ConstantInt>(V))
    O["unsigned_value"] = unsignedString(CI->getValue());
  else
    O["unsigned_value"] = unrecoverable("non_constant_operand");
  return O;
}

bool fixedAllocSize(const DataLayout &DL, Type *Ty, uint64_t &Size) {
  if (!Ty || !Ty->isSized())
    return false;
  TypeSize TS = DL.getTypeAllocSize(Ty);
  if (TS.isScalable())
    return false;
  Size = TS.getFixedSize();
  return true;
}

bool collectSlots(const DataLayout &DL, Type *Ty, uint64_t Base,
                  SmallVectorImpl<uint64_t> &Slots, std::string &Reason) {
  if (auto *PT = dyn_cast<PointerType>(Ty)) {
    if (isGCPointerType(PT))
      Slots.push_back(Base);
    return true;
  }
  if (auto *ST = dyn_cast<StructType>(Ty)) {
    if (!ST->isSized()) {
      Reason = "unsized_struct";
      return false;
    }
    const StructLayout *Layout = DL.getStructLayout(ST);
    for (unsigned I = 0, E = ST->getNumElements(); I != E; ++I)
      if (!collectSlots(DL, ST->getElementType(I),
                        Base + Layout->getElementOffset(I), Slots, Reason))
        return false;
    return true;
  }
  if (auto *AT = dyn_cast<ArrayType>(Ty)) {
    uint64_t ElementSize = 0;
    if (!fixedAllocSize(DL, AT->getElementType(), ElementSize)) {
      Reason = "unsized_array_element";
      return false;
    }
    for (uint64_t I = 0, E = AT->getNumElements(); I != E; ++I)
      if (!collectSlots(DL, AT->getElementType(), Base + I * ElementSize,
                        Slots, Reason))
        return false;
    return true;
  }
  if (isa<VectorType>(Ty) && containsGCPtrType(Ty)) {
    Reason = "gc_vector_slot_layout_unsupported";
    return false;
  }
  return true;
}

json::Array slotArray(ArrayRef<uint64_t> Slots) {
  json::Array A;
  for (uint64_t Pos : Slots)
    A.push_back(unsignedString(Pos));
  return A;
}

json::Array overlapArray(ArrayRef<uint64_t> Slots, uint64_t RefSize,
                         uint64_t Begin, uint64_t End) {
  json::Array A;
  for (uint64_t Pos : Slots) {
    bool Overflow = Pos > std::numeric_limits<uint64_t>::max() - RefSize;
    uint64_t SlotEnd = Overflow ? std::numeric_limits<uint64_t>::max()
                                : Pos + RefSize;
    bool Overlap = !Overflow && Pos < End && Begin < SlotEnd;
    A.push_back(json::Object{{"slot_begin", unsignedString(Pos)},
                             {"slot_end", unsignedString(SlotEnd)},
                             {"slot_end_overflow", Overflow},
                             {"copy_begin", unsignedString(Begin)},
                             {"copy_end", unsignedString(End)},
                             {"overlap", Overlap}});
  }
  return A;
}

json::Array gepSteps(Value *Ptr, const DataLayout &DL) {
  json::Array Steps;
  Value *Cur = Ptr;
  while (true) {
    if (auto *GEP = dyn_cast<GEPOperator>(Cur)) {
      json::Object Step{{"source_element_type",
                         typeIR(GEP->getSourceElementType())}};
      json::Array Indices;
      for (Value *Index : GEP->indices())
        Indices.push_back(valueIR(Index));
      Step["indices"] = std::move(Indices);
      APInt Segment(DL.getIndexSizeInBits(GEP->getPointerAddressSpace()), 0);
      if (GEP->accumulateConstantOffset(DL, Segment)) {
        Step["segment_negative"] = Segment.isNegative();
        Step["segment_active_bits"] =
            static_cast<int64_t>(Segment.getActiveBits());
        if (!Segment.isNegative() && Segment.getActiveBits() <= 64)
          Step["segment_byte_offset"] =
              unsignedString(Segment.getZExtValue());
        else
          Step["segment_byte_offset"] =
              unrecoverable("segment_offset_not_uint64");
      } else {
        Step["segment_byte_offset"] =
            unrecoverable("non_constant_gep_offset");
      }
      Steps.push_back(std::move(Step));
      Cur = GEP->getPointerOperand();
      continue;
    }
    if (auto *CI = dyn_cast<CastInst>(Cur)) {
      if (isa<BitCastInst>(CI) || isa<AddrSpaceCastInst>(CI)) {
        Cur = CI->getOperand(0);
        continue;
      }
    }
    if (auto *CE = dyn_cast<ConstantExpr>(Cur)) {
      if (CE->isCast()) {
        Cur = CE->getOperand(0);
        continue;
      }
    }
    break;
  }
  return Steps;
}

struct TypedCapture {
  json::Value Base = nullptr;
  json::Value CompleteType = nullptr;
  json::Value Contains = nullptr;
  json::Value Slots = nullptr;
  json::Value Overlaps = nullptr;
  json::Value Begin = nullptr;
  json::Value End = nullptr;
  json::Value AllocSize = nullptr;
  json::Value Bounds = nullptr;
};

TypedCapture captureTyped(Value *Ptr, Value *SizeValue, const DataLayout &DL,
                          uint64_t RefSize) {
  TypedCapture C;
  auto *PtrTy = dyn_cast<PointerType>(Ptr->getType());
  if (!PtrTy) {
    C.Base = C.CompleteType = C.Contains = C.Slots = C.Overlaps = C.Begin =
        C.End = C.AllocSize = C.Bounds = unrecoverable("not_a_pointer");
    return C;
  }

  APInt Offset(DL.getIndexSizeInBits(PtrTy->getAddressSpace()), 0);
  Value *Base = Ptr->stripAndAccumulateConstantOffsets(DL, Offset, true);
  C.Base = valueIR(Base);

  StringRef Reason;
  if (isa<PHINode>(Base))
    Reason = "phi_base";
  else if (isa<SelectInst>(Base))
    Reason = "select_base";
  else if (isa<IntToPtrInst>(Base) ||
           (isa<ConstantExpr>(Base) &&
            cast<ConstantExpr>(Base)->getOpcode() == Instruction::IntToPtr))
    Reason = "inttoptr_base";

  auto *BasePtrTy = dyn_cast<PointerType>(Base->getType());
  if (Reason.empty() && (!BasePtrTy || BasePtrTy->isOpaque()))
    Reason = "opaque_or_nonpointer_base";

  Type *Ty = nullptr;
  if (Reason.empty()) {
    Ty = BasePtrTy->getNonOpaquePointerElementType();
    if (Ty->isIntegerTy(8) && !isa<AllocaInst>(Base))
      Reason = "bare_i8_carrier";
    else if (!Ty->isSized())
      Reason = "unsized_complete_type";
  }

  if (!Reason.empty()) {
    C.CompleteType = C.Contains = C.Slots = C.Overlaps = C.Begin = C.End =
        C.AllocSize = C.Bounds = unrecoverable(Reason);
    return C;
  }

  C.CompleteType = typeIR(Ty);
  C.Contains = containsGCPtrType(Ty);
  uint64_t Size = 0;
  if (!fixedAllocSize(DL, Ty, Size)) {
    C.AllocSize = C.Bounds = C.Slots = C.Overlaps = C.Begin = C.End =
        unrecoverable("scalable_or_unsized_complete_type");
    return C;
  }
  C.AllocSize = unsignedString(Size);

  SmallVector<uint64_t, 8> Slots;
  std::string SlotReason;
  if (!collectSlots(DL, Ty, 0, Slots, SlotReason)) {
    C.Slots = C.Overlaps = unrecoverable(SlotReason);
  } else {
    llvm::sort(Slots);
    Slots.erase(std::unique(Slots.begin(), Slots.end()), Slots.end());
    C.Slots = slotArray(Slots);
  }

  bool Negative = Offset.isNegative();
  unsigned ActiveBits = Offset.getActiveBits();
  auto *CopySize = dyn_cast<ConstantInt>(SizeValue);
  if (Negative || ActiveBits > 64 || !CopySize ||
      CopySize->getValue().getActiveBits() > 64) {
    StringRef R = !CopySize ? "non_constant_copy_size"
                           : "range_not_representable_as_uint64";
    C.Begin = C.End = C.Bounds = unrecoverable(R);
    if (C.Slots.getAsArray())
      C.Overlaps = unrecoverable(R);
    return C;
  }

  uint64_t Begin = Offset.getZExtValue();
  uint64_t Copy = CopySize->getZExtValue();
  bool Overflow = Begin > std::numeric_limits<uint64_t>::max() - Copy;
  uint64_t End = Overflow ? std::numeric_limits<uint64_t>::max() : Begin + Copy;
  bool InBounds = !Overflow && Begin <= Size && End <= Size;
  C.Begin = unsignedString(Begin);
  C.End = unsignedString(End);
  C.Bounds = json::Object{{"negative", Negative},
                          {"active_bits", static_cast<int64_t>(ActiveBits)},
                          {"active_bits_le_64", ActiveBits <= 64},
                          {"copy_end_overflow", Overflow},
                          {"in_bounds", InBounds},
                          {"result", !Negative && ActiveBits <= 64 && InBounds}};
  if (C.Slots.getAsArray())
    C.Overlaps = overlapArray(Slots, RefSize, Begin, End);
  return C;
}

json::Object captureMemTransfer(IntrinsicInst &Call, StringRef StableModule,
                                const DataLayout &DL) {
  Value *Dst = Call.getArgOperand(0);
  Value *Src = Call.getArgOperand(1);
  Value *CopySize = Call.getArgOperand(2);
  uint64_t RefSize = DL.getPointerSize(1);

  json::Object O{{"schema", "cjir-capture-v1"},
                 {"module", StableModule.str()},
                 {"function", Call.getFunction()->getName().str()},
                 {"call_ir", instructionIR(Call)},
                 {"dst_operand_ir", valueIR(Dst)},
                 {"src_operand_ir", valueIR(Src)},
                 {"copy_size_operand", operandCapture(CopySize)},
                 {"dst_gep_steps", gepSteps(Dst, DL)},
                 {"gc_pointer_size", unsignedString(RefSize)}};

  TypedCapture SrcCapture = captureTyped(Src, CopySize, DL, RefSize);
  O["src_base_ir"] = std::move(SrcCapture.Base);
  O["src_complete_type"] = std::move(SrcCapture.CompleteType);
  O["src_contains_gc_ptr_input_type"] = O["src_complete_type"];
  O["src_contains_gc_ptr_result"] = std::move(SrcCapture.Contains);
  O["src_gc_slot_positions"] = std::move(SrcCapture.Slots);
  O["src_slot_overlap_intervals"] = std::move(SrcCapture.Overlaps);
  O["src_begin_byte_offset"] = std::move(SrcCapture.Begin);
  O["src_copy_end"] = std::move(SrcCapture.End);
  O["src_alloc_size"] = std::move(SrcCapture.AllocSize);
  O["src_bounds_result"] = std::move(SrcCapture.Bounds);

  auto *DstPtrTy = dyn_cast<PointerType>(Dst->getType());
  if (!DstPtrTy) {
    O["dst_malloc_array_root"] = unrecoverable("destination_not_pointer");
    return O;
  }

  APInt Offset(DL.getIndexSizeInBits(DstPtrTy->getAddressSpace()), 0);
  Value *Base = Dst->stripAndAccumulateConstantOffsets(DL, Offset, true);
  auto *Allocation = dyn_cast<IntrinsicInst>(Base);
  if (!Allocation || Allocation->getIntrinsicID() != Intrinsic::cj_malloc_array) {
    O["dst_malloc_array_root"] = unrecoverable(
        isa<PHINode>(Base)       ? "phi_base"
        : isa<SelectInst>(Base)  ? "select_base"
        : isa<IntToPtrInst>(Base) ? "inttoptr_base"
                                  : "not_llvm_cj_malloc_array");
    return O;
  }

  std::string Block;
  raw_string_ostream BlockOS(Block);
  Allocation->getParent()->printAsOperand(BlockOS, true);
  O["dst_malloc_array_root"] =
      json::Object{{"status", "recovered"},
                   {"call_ssa", valueIR(Allocation)},
                   {"basic_block", BlockOS.str()}};

  Value *Length = Allocation->getArgOperand(1);
  Value *Stride = Allocation->getArgOperand(2);
  O["array_length"] = operandCapture(Length);
  O["element_stride_operand"] = operandCapture(Stride);

  auto *TI = dyn_cast<GlobalVariable>(
      Allocation->getArgOperand(0)->stripPointerCasts());
  if (!TI) {
    O["typeinfo_global"] = O["related_layout_type"] =
        O["related_layout_ir"] = unrecoverable("typeinfo_not_global");
    return O;
  }
  O["typeinfo_global"] = TI->getName().str();

  StructType *Layout = getTypeLayoutType(TI);
  if (!Layout) {
    O["related_layout_type"] = O["related_layout_ir"] =
        unrecoverable("missing_related_type");
    return O;
  }
  O["related_layout_type"] = Layout->hasName() ? Layout->getName().str()
                                                  : typeIR(Layout);
  O["related_layout_ir"] = typeIR(Layout);
  if (!Layout->isSized() || Layout->getNumElements() != 2) {
    O["layout_element_alloc_size"] =
        unrecoverable("layout_not_sized_two_field_struct");
    return O;
  }
  auto *Flexible = dyn_cast<ArrayType>(Layout->getElementType(1));
  if (!Flexible || Flexible->getNumElements() != 0) {
    O["layout_element_alloc_size"] =
        unrecoverable("layout_missing_flexible_array");
    return O;
  }
  Type *ElementTy = Flexible->getElementType();
  uint64_t LayoutElementSize = 0;
  if (!fixedAllocSize(DL, ElementTy, LayoutElementSize)) {
    O["layout_element_alloc_size"] =
        unrecoverable("layout_element_unsized_or_scalable");
    return O;
  }
  O["layout_element_alloc_size"] = unsignedString(LayoutElementSize);
  O["contains_gc_ptr_input_type"] = typeIR(ElementTy);
  O["contains_gc_ptr_result"] = containsGCPtrType(ElementTy);

  auto *LengthCI = dyn_cast<ConstantInt>(Length);
  auto *StrideCI = dyn_cast<ConstantInt>(Stride);
  auto *CopyCI = dyn_cast<ConstantInt>(CopySize);
  if (!LengthCI || !StrideCI || !CopyCI ||
      LengthCI->getValue().getActiveBits() > 64 ||
      StrideCI->getValue().getActiveBits() > 64 ||
      CopyCI->getValue().getActiveBits() > 64) {
    O["length_times_stride"] =
        unrecoverable("non_constant_or_wide_array_arithmetic");
    O["dst_begin_byte_offset"] = O["dst_copy_end"] =
        O["dst_alloc_size"] = O["bounds_result"] =
            unrecoverable("array_range_not_representable");
    O["gc_slot_positions"] = O["slot_overlap_intervals"] =
        unrecoverable("array_range_not_representable");
    return O;
  }

  uint64_t Count = LengthCI->getZExtValue();
  uint64_t StrideValue = StrideCI->getZExtValue();
  bool MulOverflow = StrideValue != 0 &&
                     Count > std::numeric_limits<uint64_t>::max() / StrideValue;
  uint64_t PayloadSize = MulOverflow ? std::numeric_limits<uint64_t>::max()
                                     : Count * StrideValue;
  O["length_times_stride"] =
      json::Object{{"overflow", MulOverflow},
                   {"result", unsignedString(PayloadSize)}};

  bool Negative = Offset.isNegative();
  unsigned ActiveBits = Offset.getActiveBits();
  uint64_t Begin = (!Negative && ActiveBits <= 64) ? Offset.getZExtValue() : 0;
  uint64_t Copy = CopyCI->getZExtValue();
  bool EndOverflow = Begin > std::numeric_limits<uint64_t>::max() - Copy;
  uint64_t End = EndOverflow ? std::numeric_limits<uint64_t>::max()
                             : Begin + Copy;
  bool AllocOverflow = MulOverflow ||
                       PayloadSize > std::numeric_limits<uint64_t>::max() -
                                         static_cast<uint64_t>(ArrayHeadSize);
  uint64_t AllocSize = AllocOverflow
                           ? std::numeric_limits<uint64_t>::max()
                           : static_cast<uint64_t>(ArrayHeadSize) + PayloadSize;
  bool InBounds = !Negative && ActiveBits <= 64 && !EndOverflow &&
                  !AllocOverflow && Begin <= AllocSize && End <= AllocSize;
  O["dst_begin_byte_offset"] = unsignedString(Begin);
  O["dst_copy_end"] = unsignedString(End);
  O["dst_alloc_size"] = unsignedString(AllocSize);
  O["bounds_result"] =
      json::Object{{"negative", Negative},
                   {"active_bits", static_cast<int64_t>(ActiveBits)},
                   {"active_bits_le_64", ActiveBits <= 64},
                   {"length_times_stride_overflow", MulOverflow},
                   {"alloc_size_overflow", AllocOverflow},
                   {"copy_end_overflow", EndOverflow},
                   {"in_bounds", InBounds},
                   {"result", InBounds}};

  SmallVector<uint64_t, 8> ElementSlots;
  std::string SlotReason;
  if (!collectSlots(DL, ElementTy, 0, ElementSlots, SlotReason)) {
    O["gc_slot_positions"] = O["slot_overlap_intervals"] =
        unrecoverable(SlotReason);
    return O;
  }
  SmallVector<uint64_t, 8> Slots;
  if (!MulOverflow && StrideValue == LayoutElementSize) {
    for (uint64_t I = 0; I != Count; ++I)
      for (uint64_t Relative : ElementSlots) {
        uint64_t Pos = static_cast<uint64_t>(ArrayHeadSize) +
                       I * StrideValue + Relative;
        Slots.push_back(Pos);
      }
  } else if (StrideValue != LayoutElementSize) {
    O["gc_slot_positions"] = O["slot_overlap_intervals"] =
        unrecoverable("stride_does_not_match_layout_element_alloc_size");
    return O;
  }
  llvm::sort(Slots);
  Slots.erase(std::unique(Slots.begin(), Slots.end()), Slots.end());
  O["gc_slot_positions"] = slotArray(Slots);
  O["slot_overlap_intervals"] = overlapArray(Slots, RefSize, Begin, End);
  return O;
}

} // namespace

int main(int Argc, char **Argv) {
  InitLLVM X(Argc, Argv);
  cl::ParseCommandLineOptions(Argc, Argv,
                              "capture CJIR memtransfer proof inputs\n");
  LLVMContext Context;
  SMDiagnostic Err;
  std::unique_ptr<Module> M = parseIRFile(InputFilename, Err, Context);
  if (!M) {
    Err.print(Argv[0], errs());
    return 1;
  }

  const DataLayout &DL = M->getDataLayout();
  for (Function &F : *M) {
    if (!F.hasCangjieGC())
      continue;
    for (BasicBlock &BB : F)
      for (Instruction &I : BB) {
        auto *II = dyn_cast<IntrinsicInst>(&I);
        if (!II || (II->getIntrinsicID() != Intrinsic::memcpy &&
                    II->getIntrinsicID() != Intrinsic::memmove))
          continue;
        json::Object Record = captureMemTransfer(*II, ModuleName, DL);
        outs() << "CJIR_CAPTURE\t"
               << formatv("{0}", json::Value(std::move(Record))) << '\n';
      }
  }
  return 0;
}
