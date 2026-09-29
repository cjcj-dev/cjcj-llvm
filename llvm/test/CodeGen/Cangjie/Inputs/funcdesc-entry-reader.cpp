// Standalone paired-ABI check. Build against the pinned runtime's shipped
// headers and library; pass a real llc-linked ELF, symbol and #StackSize.
// The same reader ELF consumes candidate, cut and restored producer output.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <link.h>
#include "StackMap/StackMap.h"

using namespace MapleRuntime;

int main(int argc, char **argv) {
  if (argc != 4)
    return 2;
  void *image = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
  if (!image) {
    std::fprintf(stderr, "INPUT_LOAD_FAILURE %s\n", dlerror());
    return 2;
  }
  void *entry = dlsym(image, argv[2]);
  Dl_info imageInfo{};
  ElfW(Sym) *symbol = nullptr;
  if (!entry || !dladdr1(entry, &imageInfo, reinterpret_cast<void **>(&symbol),
                         RTLD_DL_SYMENT) || !symbol)
    return 2;
  const Uptr pc = reinterpret_cast<Uptr>(entry);
  if (!ElfUnloadQuiescence::LinkImage(pc))
    return 2;
  const auto desc = MFuncDesc::GetFuncDesc(pc);
  // A cut entry slot can point outside the image. Keep that target failure
  // readable rather than dereferencing an invalid descriptor in the checker.
  Dl_info descInfo{};
  const bool mapped = desc && dladdr(desc, &descInfo) &&
                      descInfo.dli_fbase == imageInfo.dli_fbase;
  const bool codeSize = mapped && desc->GetCodeSize() == symbol->st_size;
  const bool expectPoll = std::strcmp(argv[2], "slot_gc_leaf") != 0;
  const bool poll = codeSize && desc->HasReturnPoll() == expectPoll;
  const auto map = codeSize ? desc->GetStackMap() : nullptr;
  Dl_info mapInfo{};
  const bool mapMapped = map && dladdr(map, &mapInfo) &&
                        mapInfo.dli_fbase == imageInfo.dli_fbase;
  const unsigned expectedFrame = std::strtoul(argv[3], nullptr, 10);
  unsigned observedFrame = 0;
  if (mapMapped)
    observedFrame = FramePrologue(map).GetFrameSize();
  const bool frame = mapMapped && observedFrame == expectedFrame;
  std::printf("%s descriptor_code_size symbol=%s present=%d size=%u st_size=%zu\n",
              codeSize ? "PASS" : "FAIL", argv[2], desc != nullptr,
              mapped ? desc->GetCodeSize() : 0, size_t(symbol->st_size));
  std::printf("%s return_poll symbol=%s expected=%d\n",
              poll ? "PASS" : "FAIL", argv[2], expectPoll);
  std::printf("%s stackmap_frame symbol=%s present=%d frame=%u expected=%u\n",
              frame ? "PASS" : "FAIL", argv[2], map != nullptr,
              observedFrame, expectedFrame);
  if (mapMapped) {
    const StackMapBuilder builder(pc, pc, 0);
    const bool valid = builder.Build<HeapReferenceMap>().IsValid();
    std::printf("BUILD_OBSERVED symbol=%s entry_pc_valid=%d\n", argv[2], valid);
  }
  return codeSize && poll && frame ? 0 : 1;
}
