//===- WasmObjcopy.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ObjCopy/wasm/WasmObjcopy.h"
#include "WasmObject.h"
#include "WasmReader.h"
#include "WasmWriter.h"
#include "llvm/ObjCopy/CommonConfig.h"
#include "llvm/Support/Errc.h"
#include "llvm/Support/FileOutputBuffer.h"
#include "llvm/Support/LEB128.h"
#include "llvm/Support/raw_ostream.h"

namespace llvm {
namespace objcopy {
namespace wasm {

using namespace object;
using SectionPred = std::function<bool(const Section &Sec)>;

static bool isDebugSection(const Section &Sec) {
  return Sec.Name.startswith(".debug");
}

static bool isLinkerSection(const Section &Sec) {
  return Sec.Name.startswith("reloc.") || Sec.Name == "linking";
}

static bool isNameSection(const Section &Sec) { return Sec.Name == "name"; }

// Sections which are known to be "comments" or informational and do not affect
// program semantics.
static bool isCommentSection(const Section &Sec) {
  return Sec.Name == "producers";
}

static Error dumpSectionToFile(StringRef SecName, StringRef Filename,
                               Object &Obj) {
  for (const Section &Sec : Obj.Sections) {
    if (Sec.Name == SecName) {
      ArrayRef<uint8_t> Contents = Sec.Contents;
      Expected<std::unique_ptr<FileOutputBuffer>> BufferOrErr =
          FileOutputBuffer::create(Filename, Contents.size());
      if (!BufferOrErr)
        return BufferOrErr.takeError();
      std::unique_ptr<FileOutputBuffer> Buf = std::move(*BufferOrErr);
      std::copy(Contents.begin(), Contents.end(), Buf->getBufferStart());
      if (Error E = Buf->commit())
        return E;
      return Error::success();
    }
  }
  return createStringError(errc::invalid_argument, "section '%s' not found",
                           SecName.str().c_str());
}

static void removeSections(const CommonConfig &Config, Object &Obj) {
  SectionPred RemovePred = [](const Section &) { return false; };

  // Explicitly-requested sections.
  if (!Config.ToRemove.empty()) {
    RemovePred = [&Config](const Section &Sec) {
      return Config.ToRemove.matches(Sec.Name);
    };
  }

  if (Config.StripDebug) {
    RemovePred = [RemovePred](const Section &Sec) {
      return RemovePred(Sec) || isDebugSection(Sec);
    };
  }

  if (Config.StripAll) {
    RemovePred = [RemovePred](const Section &Sec) {
      return RemovePred(Sec) || isDebugSection(Sec) || isLinkerSection(Sec) ||
             isNameSection(Sec) || isCommentSection(Sec);
    };
  }

  if (Config.OnlyKeepDebug) {
    RemovePred = [&Config](const Section &Sec) {
      // Keep debug sections, unless explicitly requested to remove.
      // Remove everything else, including known sections.
      return Config.ToRemove.matches(Sec.Name) || !isDebugSection(Sec);
    };
  }

  if (!Config.OnlySection.empty()) {
    RemovePred = [&Config](const Section &Sec) {
      // Explicitly keep these sections regardless of previous removes.
      // Remove everything else, inluding known sections.
      return !Config.OnlySection.matches(Sec.Name);
    };
  }

  if (!Config.KeepSection.empty()) {
    RemovePred = [&Config, RemovePred](const Section &Sec) {
      // Explicitly keep these sections regardless of previous removes.
      if (Config.KeepSection.matches(Sec.Name))
        return false;
      // Otherwise defer to RemovePred.
      return RemovePred(Sec);
    };
  }

  Obj.removeSections(RemovePred);
}

static Error malformedLinking(const Twine &Why) {
  return createStringError(errc::invalid_argument,
                           "malformed wasm linking section: " + Why);
}

// --localize-symbols for wasm relocatable objects: rewrite the binding of the
// matching *defined* symbols in the "linking" section symbol table to LOCAL
// (clearing WEAK/EXPORTED), exactly what ELF objcopy does for `ld -r` output.
// All other subsections and every symbol body are copied byte for byte.
static Error localizeSymbols(const CommonConfig &Config, Object &Obj) {
  using namespace llvm::wasm;
  for (Section &Sec : Obj.Sections) {
    if (Sec.SectionType != WASM_SEC_CUSTOM || Sec.Name != "linking")
      continue;
    const uint8_t *P = Sec.Contents.begin();
    const uint8_t *End = Sec.Contents.end();
    auto ReadU = [&](const uint8_t *Limit, uint64_t &V) -> Error {
      unsigned N = 0;
      const char *Err = nullptr;
      V = decodeULEB128(P, &N, Limit, &Err);
      if (Err)
        return malformedLinking(Err);
      P += N;
      return Error::success();
    };
    SmallVector<char, 0> Out;
    raw_svector_ostream OS(Out);
    uint64_t Version;
    if (Error E = ReadU(End, Version))
      return E;
    encodeULEB128(Version, OS);
    while (P < End) {
      uint8_t Type = *P++;
      uint64_t Len;
      if (Error E = ReadU(End, Len))
        return E;
      if (Len > uint64_t(End - P))
        return malformedLinking("subsection exceeds section size");
      const uint8_t *SubEnd = P + Len;
      if (Type != WASM_SYMBOL_TABLE) {
        OS.write(char(Type));
        encodeULEB128(Len, OS);
        OS.write(reinterpret_cast<const char *>(P), Len);
        P = SubEnd;
        continue;
      }
      SmallVector<char, 0> Sub;
      raw_svector_ostream SOS(Sub);
      uint64_t Count;
      if (Error E = ReadU(SubEnd, Count))
        return E;
      encodeULEB128(Count, SOS);
      for (uint64_t I = 0; I < Count; ++I) {
        if (P >= SubEnd)
          return malformedLinking("truncated symbol table");
        uint8_t Kind = *P++;
        uint64_t Flags;
        if (Error E = ReadU(SubEnd, Flags))
          return E;
        const uint8_t *Body = P;
        bool Undefined = Flags & WASM_SYMBOL_UNDEFINED;
        StringRef Name;
        bool HasName = false;
        uint64_t Tmp;
        auto ReadName = [&]() -> Error {
          uint64_t L;
          if (Error E = ReadU(SubEnd, L))
            return E;
          if (L > uint64_t(SubEnd - P))
            return malformedLinking("symbol name exceeds subsection");
          Name = StringRef(reinterpret_cast<const char *>(P), L);
          P += L;
          HasName = true;
          return Error::success();
        };
        switch (Kind) {
        case WASM_SYMBOL_TYPE_FUNCTION:
        case WASM_SYMBOL_TYPE_GLOBAL:
        case WASM_SYMBOL_TYPE_TAG:
        case WASM_SYMBOL_TYPE_TABLE:
          if (Error E = ReadU(SubEnd, Tmp))
            return E;
          if (!Undefined || (Flags & WASM_SYMBOL_EXPLICIT_NAME))
            if (Error E = ReadName())
              return E;
          break;
        case WASM_SYMBOL_TYPE_DATA:
          if (Error E = ReadName())
            return E;
          if (!Undefined)
            for (int K = 0; K < 3; ++K) // segment, offset, size
              if (Error E = ReadU(SubEnd, Tmp))
                return E;
          break;
        case WASM_SYMBOL_TYPE_SECTION:
          if (Error E = ReadU(SubEnd, Tmp))
            return E;
          break;
        default:
          return malformedLinking("unknown symbol kind " + Twine(unsigned(Kind)));
        }
        if (HasName && !Undefined && Config.SymbolsToLocalize.matches(Name))
          Flags = (Flags & ~uint64_t(WASM_SYMBOL_BINDING_MASK |
                                     WASM_SYMBOL_EXPORTED)) |
                  WASM_SYMBOL_BINDING_LOCAL;
        SOS.write(char(Kind));
        encodeULEB128(Flags, SOS);
        SOS.write(reinterpret_cast<const char *>(Body), P - Body);
      }
      if (P != SubEnd)
        return malformedLinking("symbol table size mismatch");
      OS.write(char(Type));
      encodeULEB128(Sub.size(), OS);
      OS.write(Sub.data(), Sub.size());
    }
    std::unique_ptr<MemoryBuffer> Buf = MemoryBuffer::getMemBufferCopy(
        StringRef(Out.data(), Out.size()), "linking");
    Sec.Contents = makeArrayRef<uint8_t>(
        reinterpret_cast<const uint8_t *>(Buf->getBufferStart()),
        Buf->getBufferSize());
    Obj.takeOwnership(std::move(Buf));
  }
  return Error::success();
}

static Error handleArgs(const CommonConfig &Config, Object &Obj) {
  // Only support AddSection, DumpSection, RemoveSection for now.
  for (StringRef Flag : Config.DumpSection) {
    StringRef SecName;
    StringRef FileName;
    std::tie(SecName, FileName) = Flag.split("=");
    if (Error E = dumpSectionToFile(SecName, FileName, Obj))
      return createFileError(FileName, std::move(E));
  }

  removeSections(Config, Obj);

  if (!Config.SymbolsToLocalize.empty())
    if (Error E = localizeSymbols(Config, Obj))
      return E;

  for (const NewSectionInfo &NewSection : Config.AddSection) {
    Section Sec;
    Sec.SectionType = llvm::wasm::WASM_SEC_CUSTOM;
    Sec.Name = NewSection.SectionName;

    std::unique_ptr<MemoryBuffer> BufferCopy = MemoryBuffer::getMemBufferCopy(
        NewSection.SectionData->getBufferStart(),
        NewSection.SectionData->getBufferIdentifier());
    Sec.Contents = makeArrayRef<uint8_t>(
        reinterpret_cast<const uint8_t *>(BufferCopy->getBufferStart()),
        BufferCopy->getBufferSize());

    Obj.addSectionWithOwnedContents(Sec, std::move(BufferCopy));
  }

  return Error::success();
}

Error executeObjcopyOnBinary(const CommonConfig &Config, const WasmConfig &,
                             object::WasmObjectFile &In, raw_ostream &Out) {
  Reader TheReader(In);
  Expected<std::unique_ptr<Object>> ObjOrErr = TheReader.create();
  if (!ObjOrErr)
    return createFileError(Config.InputFilename, ObjOrErr.takeError());
  Object *Obj = ObjOrErr->get();
  assert(Obj && "Unable to deserialize Wasm object");
  if (Error E = handleArgs(Config, *Obj))
    return E;
  Writer TheWriter(*Obj, Out);
  if (Error E = TheWriter.write())
    return createFileError(Config.OutputFilename, std::move(E));
  return Error::success();
}

} // end namespace wasm
} // end namespace objcopy
} // end namespace llvm
