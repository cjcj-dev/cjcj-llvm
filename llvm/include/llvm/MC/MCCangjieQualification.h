//===- MCCangjieQualification.h - CJ final layout records --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef LLVM_MC_MCCANGJIEQUALIFICATION_H
#define LLVM_MC_MCCANGJIEQUALIFICATION_H

#include "llvm/ADT/SmallVector.h"
#include <cstdint>

namespace llvm {
class MCSymbol;

// Symbols delimit actual emitted instructions, including expanded pseudos.
// Events are in physical emission order. At a shared address the last event
// describes the next instruction; a zero-length padding interval therefore
// contributes no interval. CFG must-state is computed by the producer, not MC.
struct MCCangjieLayoutEvent {
  const MCSymbol *PC;
  uint32_t Bits;
};
struct MCCangjieSite {
  const MCSymbol *PC;
  uint16_t Kind;
  uint16_t Bits;
};
struct MCCangjieQualification {
  const MCSymbol *Entry;
  const MCSymbol *End;
  SmallVector<MCCangjieLayoutEvent, 16> Events;
  SmallVector<MCCangjieSite, 8> Sites;
};
} // namespace llvm
#endif
