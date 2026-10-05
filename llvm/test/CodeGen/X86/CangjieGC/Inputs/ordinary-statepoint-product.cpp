// Consume an LLVM-produced image through the shipped runtime metadata registry
// and GC map consumers. No stackmap parser is compiled into this executable.
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>
#include "CangjieRuntime.h"
#include "Loader/ElfUnloadQuiescence.h"
#include "Mutator/Mutator.h"
#include "UnwindStack/StackFrameCursor.h"
#include "StackMap/StackMap.h"
using namespace MapleRuntime;

int main(int argc, char** argv)
{
    if (argc != 3) { return 2; }
    const bool neighbor = !std::strcmp(argv[2], "neighbor");
    const bool root = !std::strcmp(argv[2], "ordinary_root");
    const bool ret = !std::strncmp(argv[2], "return_", 7);
    const bool retRoot = !std::strcmp(argv[2], "return_root");
    const char* name = neighbor ? "ordinary_empty" : argv[2];
    void* image = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    if (!image) { std::fprintf(stderr, "LOAD_FAILURE %s\n", dlerror()); return 2; }
    const Uptr entry = reinterpret_cast<Uptr>(dlsym(image, name));
    const Uptr metadata = reinterpret_cast<Uptr>(dlsym(image, "_CJMetadataStart"));
    if (!entry || !metadata || !ElfUnloadQuiescence::LinkImage(metadata)) { return 2; }
    ElfUnloadQuiescence::ReadScope reader;
    Uptr site = 0;
    const U16 kind = ret ? 3 : 1;
    for (Uptr off = 0; off < 128; ++off) {
        const auto m = ElfUnloadQuiescence::FindFrameMetadata(entry + off, kind);
        if (m.entry == entry && m.descriptor && m.match == ElfUnloadQuiescence::QualificationMatch::SAVED_SITE) {
            site = entry + off; break;
        }
    }
    if (!site) { std::fprintf(stderr, "QUALIFICATION_FAILURE\n"); return 2; }
    if (neighbor) { ++site; }
    CangjieRuntime::stackGrowConfig = StackGrowConfig::STACK_GROW_ON;
    alignas(16) Uptr storage[64] {};
    auto* fp = storage + 56;
    fp[-1] = entry + 9;
    fp[-3] = 0x10000;
    MachineFrame machine;
    machine.SetFA(reinterpret_cast<FrameAddress*>(fp));
    machine.SetSP(reinterpret_cast<Uptr>(storage));
    // Qualify the actual saving event. The neighbor is only a map lookup,
    // not a live frame at an epilogue whose layout has already been cleared.
    machine.SetIP(reinterpret_cast<const uint32_t*>(site - neighbor));
    FrameInfo frame(machine, ret ? FrameType::RETURN_SAFEPOINT : FrameType::MANAGED);
    // Return frames are consumed by their own saved-stub path, which resolves
    // the descriptor in CollectReturnRegisterRoots without a managed layout.
    if (!ret && !frame.ResolveProcInfo(kind)) { return 2; }
    Dl_info loaded {};
    dladdr(reinterpret_cast<void*>(&StackFrameCursor::ProcessManagedFrame), &loaded);
    std::fprintf(stderr, "PRODUCT_LOADED=%s TARGET_ENTER=%s savedPC=%lu testedPC=%lu\n",
                 loaded.dli_fname, argv[2], (unsigned long)(site-entry-neighbor), (unsigned long)(site-entry));
    bool result = false;
    if (ret) {
        fp[-1] = retRoot ? 0x10000 : 0;
        fp[-10] = entry; fp[-11] = site;
        std::vector<StackFrameCursor::ReturnRegisterRoot> roots;
        StackFrameCursor::CollectReturnRegisterRoots(frame, roots);
        result = retRoot ? roots.size() == 1 && roots[0].slot == reinterpret_cast<ObjectRef*>(fp-1) &&
            reinterpret_cast<Uptr>(roots[0].object) == 0x10000 : roots.empty();
        std::fprintf(stderr, "PRODUCT_RESULT roots=%zu\n", roots.size());
    } else {
        // Invoke the actual exported product method, avoiding a header-inline
        // parser copy. The same method supplies ProcessManagedFrame's guard.
        using Reason = StackMapInvalidReason (*)(const StackMapBuilder*);
        const auto reasonFn = reinterpret_cast<Reason>(dlsym(RTLD_DEFAULT,
            "_ZNK12MapleRuntime15StackMapBuilder16GetInvalidReasonEv"));
        if (!reasonFn) { return 2; }
        StackMapBuilder builder(entry, site, reinterpret_cast<Uptr>(fp),
            reinterpret_cast<uint64_t*>(frame.GetQualifiedDescriptor()));
        const auto reason = reasonFn(&builder);
        std::fprintf(stderr, "PRODUCT_RESULT invalidReason=%u\n", unsigned(reason));
        if (neighbor) {
            result = reason == StackMapInvalidReason::PC_MISS;
        } else if (root || reason == StackMapInvalidReason::ZERO_ROOT_INDICES) {
            size_t visits = 0;
            bool exactSlot = true;
            RootVisitor visitor = [&](RootSlot& slot) {
                ++visits;
                exactSlot &= reinterpret_cast<void*>(&slot) == reinterpret_cast<void*>(fp-3);
            };
            DerivedPtrVisitor derived = [](zaddress_unsafe, DerivedSlot&) {};
            Mutator mutator;
            RegSlotsMap registers;
            StackFrameCursor::ProcessManagedFrame(visitor, &derived, registers, frame, mutator);
            result = root ? visits == 1 && exactSlot : visits == 0;
            std::fprintf(stderr, "PRODUCT_RESULT visits=%zu exactSlot=%d\n", visits, exactSlot);
        }
    }
    std::fprintf(stderr, "TARGET_ASSERT=%s assertion-executed result=%d\n", argv[2], result);
    return result ? 0 : 1;
}
