# MachO FuncDesc map ABI

Darwin and iOS 64-bit Cangjie objects publish `__CJ_METADATA,__cjfuncmap`.
Each record is exactly 16 bytes, aligned to 8, with target-endian fields:

| Offset | Type | Meaning |
| --- | --- | --- |
| 0 | u64 | relocated startPC, the `FuncBegin` also published by return polls |
| 8 | u64 | relocated pointer to this function's existing FuncDesc |

There is no header, count, terminator, version word, or function-entry prefix.
The image's section size divided by 16 gives the count. dyld applies the image
slide to the pointers. The producer is `CJMetadataInfo::emitDatas`; it uses the
same descriptor symbol that it defines, including the package-qualified MachO
name. Ordinary and `cjinit` functions use the same record layout. Functions
without Cangjie GC or with `leaf-function` are excluded by `recordCurrentFunc`.
The existing descriptor layout is unchanged.

Each record has a linker-private, non-temporary symbol and lives in a regular
section with `S_ATTR_LIVE_SUPPORT`. This makes the record a separate linker atom:
a live function (or its live descriptor) keeps the record; the record keeps its
descriptor. A record whose references are both dead is discarded. This does not
force unreferenced functions live. Exported functions/descriptors are naturally
live under the linker's export policy. Ordinary object concatenation merges the
sections from multiple input modules. Archive member extraction follows normal
symbol references: the table does not force loading otherwise unused members.

**File order is not address order.** Linkers can reorder functions independently
of records, and `cjinit` has its own code section. Per cjcj-llvm#81's 0927 18:5x
ruling, cangjie-runtime#1207 owns image-load collection and sorting by relocated
startPC. It must build the PC index before publishing that image for lookup, and
remove it on unload; lookups must not read a removed return frame. This matches
the runtime PC-index responsibility in HotSpot `codeCache.cpp:750-755`, without
claiming that LLVM's static metadata implements HotSpot's dynamic CodeHeap.
No runtime consumer is implemented in this LLVM change.

The native test links actual llc-produced objects on both macOS architectures,
including two modules, reordered code, and `-dead_strip` with restricted exports.
It compares every record with the final image's function and descriptor symbols.
The producer cut removes record fields; the consumer cut supplies `FuncEnd`
instead of `FuncBegin` at the existing `emitDatas` calls. Both must reach and fail
`FUNC_MAP_TARGET`; candidate and restored must pass with identical input objects.
The baseline must reach the same assertion with no map. `native.py` preserves
MachO files, symbol/section dumps, product identities and each target result.
The independent PAIR_RETURN_TARGET experiment belongs to #74 after #1207 lands.
