# Paired runtime layout

Configure this LLVM fork with `-DCANGJIE_RUNTIME_SOURCE_DIR=/path/to/runtime-repository`.
The repository must contain `runtime/tools/generate-runtime-layout.py` and the
runtime sources whose compiled assertions define the ABI. Configure and every
incremental LLVM build check `include/llvm/CodeGen/CangjieRuntimeLayout.h` against
those assertions. Native tools built during cross compilation inherit the same
runtime source directory.

After an intentional paired ABI update, refresh the compiler copy with:

```
python3 /path/to/runtime-repository/runtime/tools/generate-runtime-layout.py \
  --write --header llvm/include/llvm/CodeGen/CangjieRuntimeLayout.h
```

Build the paired runtime as well: header synchronization does not prove C++
layout. TypeInfo offsets describe the 64-bit ABI; they do not validate ARM32.
The cjcj LLVM/runtime pins and CI callers must be upgraded together (cjcj#637).
Do not infer full-chain ABI closure from this LLVM header check alone.
