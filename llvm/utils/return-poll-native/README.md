# Native return-poll root experiment

The input follows runtime's `runtime/tests/gc_unit/return_poll_pair.cpp`.
`pair.cpp` initializes the same runtime context and arms a real handshake. Its
closure visits the runtime's roots and replaces the returned reference. The
assertion observes the value returned by the LLVM-generated `ref_ret`; the
bridge only supplies the managed TLS register and native ABI stack alignment.
The test does not assemble a poll, manufacture a stack map, or replace a runtime
entry. It tests root preservation through the handshake, not a complete GC cycle.

`objects.json` contains actual cross-target object bytes emitted on the LLVM
build host, so the native runners need not rebuild LLVM. It is an input artifact,
not expected output. Each object records its successful compiler invocation,
producer hash, input hash, and object hash. The ordinary and producer-cut llc
binaries are identified by the LLVM #74 implementation report. The producer cut
restricts the existing `emitInstruction` return routes to Linux. To regenerate:

```
python3 llvm/utils/return-poll-native/emit.py --tools /path/to/retained-tools \
  --out /path/to/output --source-root /path/to/llvm-checkout
cp /path/to/output/objects.json llvm/utils/return-poll-native/objects.json
```

`native.py` checks the input identities, builds the pinned runtime and a private
consumer-cut copy concurrently, and links the objects on each native runner.
The consumer cut disconnects `CollectReturnRegisterRoots` in the product's
`HandleReturnSafepoint`. The runtime checkout itself is unchanged. Four arms run
in separate directories: candidate, producer cut, consumer cut, restored.
Candidate/consumer/restored use the same executable; candidate/producer/restored
use the same runtime library. Restored reuses the immutable candidate artifacts.
A successful link or an early failure is never counted as the target assertion.
Every arm must print `PAIR_RETURN_TARGET`; both cuts must return 1 there, and both
normal arms must return 0. Compiler, linker, runtime, hash and cache logs are
uploaded even when a job fails.

The GHA workflow runs macOS arm64, macOS x86_64 and Windows x86_64. iOS object
format checks remain in `return-poll-formats.ll`; macOS execution is not evidence
of iOS execution. The workflow's runtime pin is the merged runtime #1178 commit.
