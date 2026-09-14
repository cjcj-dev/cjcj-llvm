GC-enabled static reference and aggregate writes could be lowered to a raw store or memcpy while the GC phase was idle. Keep both intrinsics on the existing `CJ_MCC_WriteStaticRef` / `CJ_MCC_WriteStaticStruct` path in every phase, matching ZGC's native-root store-good contract (`zBarrierSet.inline.hpp:265`). Existing atomic runtime calls and ordering operands are preserved.

Adds O0/O2 IR and assembly regression coverage for initialization, subsequent reference writes, aggregate writes, and atomic ABI preservation. Validation includes product compiler builds, producer/consumer fault-injection arms, and replay of the same Cangjie frontend bitcode through opt→llc→ld. Detailed results will be recorded in the lane report before review.

Fixes #1.
