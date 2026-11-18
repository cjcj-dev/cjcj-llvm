; RUN: opt -mtriple=x86_64-unknown-linux-gnu -cangjie-pipeline -passes=cj-runtime-lowering -S %s | FileCheck %s
; RUN: opt -mtriple=x86_64-unknown-linux-gnu -passes=cj-runtime-lowering -S %s | FileCheck %s
;
; A foreign callee that loses "cj2c" is called directly, outside any
; saferegion, so a stop-the-world pause waits until it returns. A libc name
; recognized by TargetLibraryInfo proves neither that the callee cannot block
; (read, flockfile, pclose) nor which implementation is bound (malloc and
; strdup may reach an interposed allocator), so every ordinary foreign callee
; keeps its C2N stub, with or without the Cangjie pipeline.

declare i64 @read(i32, ptr, i64) "cj2c"
declare i64 @write(i32, ptr, i64) "cj2c"
declare i32 @system(ptr) "cj2c"
declare i32 @pclose(ptr) "cj2c"
declare void @flockfile(ptr) "cj2c"
declare ptr @malloc(i64) "cj2c"
declare ptr @strdup(ptr) "cj2c"
declare i64 @strlen(ptr) "cj2c"
declare double @sqrt(double) "cj2c"
declare i64 @cj_test_native(ptr) "cj2c"

; CHECK-DAG: @read.CJStubGV = internal global ptr @read
; CHECK-DAG: @write.CJStubGV = internal global ptr @write
; CHECK-DAG: @system.CJStubGV = internal global ptr @system
; CHECK-DAG: @pclose.CJStubGV = internal global ptr @pclose
; CHECK-DAG: @flockfile.CJStubGV = internal global ptr @flockfile
; CHECK-DAG: @malloc.CJStubGV = internal global ptr @malloc
; CHECK-DAG: @strdup.CJStubGV = internal global ptr @strdup
; CHECK-DAG: @strlen.CJStubGV = internal global ptr @strlen
; CHECK-DAG: @sqrt.CJStubGV = internal global ptr @sqrt
; CHECK-DAG: @cj_test_native.CJStubGV = internal global ptr @cj_test_native
; The attribute itself survives, so the backend still routes through the stub.
; CHECK-DAG: declare {{.*}}i64 @read(i32, ptr, i64) #[[ATTR:[0-9]+]]
; CHECK-DAG: declare {{.*}}ptr @malloc(i64) #[[ATTR]]
; CHECK-DAG: declare {{.*}}i64 @strlen(ptr) #[[ATTR]]
; CHECK-DAG: attributes #[[ATTR]] = { "cj2c" }

define i64 @use(i32 %fd, ptr %buf, i64 %n) {
entry:
  %r = call i64 @read(i32 %fd, ptr %buf, i64 %n)
  %w = call i64 @write(i32 %fd, ptr %buf, i64 %r)
  %s = call i32 @system(ptr %buf)
  %c = call i32 @pclose(ptr %buf)
  call void @flockfile(ptr %buf)
  %a = call ptr @malloc(i64 %n)
  %d = call ptr @strdup(ptr %a)
  %l = call i64 @strlen(ptr %d)
  %q = call double @sqrt(double 2.0)
  %t = call i64 @cj_test_native(ptr %buf)
  ret i64 %w
}
