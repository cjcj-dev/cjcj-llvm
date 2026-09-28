// Execute the llc-emitted thread_id function with three real TLS inputs.
// Linux AArch64 syscall-only driver; no libc or replacement thread-id helper.
.text
.global _start
_start:
  mov x0, #0x100000000
  mov x1, #4096
  mov x2, #3
  mov x3, #0x32
  mov x4, #-1
  mov x5, #0
  mov x8, #222
  svc #0
  mov x20, x0
  mov x1, #0x100000000
  cmp x20, x1
  b.ne setup_failed
  adrp x28, tls
  add x28, x28, :lo12:tls
  adrp x21, results
  add x21, x21, :lo12:results
  // Null pointer: the result must remain zero.
  str xzr, [x28, #16]
  bl thread_id
  str x0, [x21]
  // Nonnull with zero low 32 bits. The old 32-bit check returns the address.
  mov x1, #0x1234
  str x1, [x20, #456]
  str x20, [x28, #16]
  bl thread_id
  str x0, [x21, #8]
  // Ordinary nonnull input is an independent positive control.
  add x20, x20, #16
  mov x1, #0x5678
  str x1, [x20, #456]
  str x20, [x28, #16]
  bl thread_id
  str x0, [x21, #16]
  mov x0, #1
  mov x1, x21
  mov x2, #24
  mov x8, #64
  svc #0
  cmp x0, #24
  b.ne setup_failed
  mov x0, #0
  b exit
setup_failed:
  mov x0, #2
exit:
  mov x8, #93
  svc #0
.bss
.balign 16
tls: .skip 64
results: .skip 24
