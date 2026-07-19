//===- CangjieDemangleStub.cpp - Passthrough Cangjie demangler ------------===//
//
// cjcj's toolchain does not need Cangjie symbol demangling or code obfuscation.
// The demangled name is consumed only to format diagnostic and error messages
// (DiagnosticInfo, X86/AArch64 FrameLowering report_fatal_error on the >2GB stack
// path, and the inert obfuscation config); it never affects the emitted machine
// code. This passthrough returns the mangled name unchanged, which removes the
// prebuilt libcangjie-demangle.a from the build while leaving generated code
// byte-identical. Build from pure source.
//
//===----------------------------------------------------------------------===//

#include "CangjieDemangle.h"

namespace Cangjie {

std::string DemangleData::GetPkgName() const { return pkgName; }
std::string DemangleData::GetFullName() const { return fullName; }
bool DemangleData::IsFunctionLike() const { return isFunctionLike; }
bool DemangleData::IsValid() const { return isValid; }
void DemangleData::SetPrivateDeclaration(bool isPrivate) {
  isPrivateDeclaration = isPrivate;
}
bool DemangleData::IsPrivateDeclaration() const { return isPrivateDeclaration; }

static DemangleData Passthrough(const std::string &mangled) {
  // pkgName empty, fullName = the mangled name verbatim, not function-like, valid.
  return DemangleData(std::string(), mangled, false, true);
}

DemangleData Demangle(const std::string &mangled,
                      const std::vector<std::string> &) {
  return Passthrough(mangled);
}

DemangleData Demangle(const std::string &mangled, const std::string &,
                      const std::vector<std::string> &) {
  return Passthrough(mangled);
}

DemangleData Demangle(const std::string &mangled) { return Passthrough(mangled); }

DemangleData Demangle(const std::string &mangled, const std::string &) {
  return Passthrough(mangled);
}

DemangleData DemangleType(const std::string &mangled) {
  return Passthrough(mangled);
}

DemangleData DemangleType(const std::string &mangled, const std::string &) {
  return Passthrough(mangled);
}

} // namespace Cangjie
