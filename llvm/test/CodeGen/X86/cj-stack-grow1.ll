; RUN: llc -O2 --cangjie-pipeline -mtriple x86_64-pc-linux-gnu  < %s  | FileCheck %s

%record = type { i64, i8 addrspace(1)* }

declare void @cj_stack_grow()

declare void @test(i8 addrspace(1)*, %record addrspace(1)*) #0 gc "cangjie"

define i64 @foo(i8 addrspace(1)* %a) #0 gc "cangjie" {
; CHECK:          subq    $24, %rsp
; CHECK-NEXT:     callq   cj_stack_grow@PLT
; CHECK-LABEL:  .Ltmp1:
; CHECK-NEXT:     xorps   %xmm0, %xmm0
; CHECK-NEXT:     movaps  %xmm0, -32(%rbp)
; CHECK-NEXT:     leaq    -32(%rbp), %rsi
; CHECK-NEXT:     xorl    %edi, %edi
; CHECK-NEXT:     callq   test@PLT
; CHECK-LABEL:  .Ltmp2:

; The return poll adds its own PC row after the callsite rows. It has no
; roots for this integer return and must not change the record slot table.
; CHECK-LABEL:  .Lstack_map.foo:
; CHECK:          #StackMapItem nums:3
; CHECK:          .long   .Ltmp2-foo
; CHECK-NEXT:     #[RegIdx: -1, SlotIdx: 0, LNIdx: -1, DerivedStartIdx: -1, SPRegIdx: -1, SPSlotIdx: -1]
; CHECK-NEXT:     .byte   2
; CHECK-NEXT:     .long   .Lcj_return_pc{{[0-9]+}}-foo
; CHECK-NEXT:     #[RegIdx: -1, SlotIdx: -1, LNIdx: -1, DerivedStartIdx: -1, SPRegIdx: -1, SPSlotIdx: -1]
; CHECK-NEXT:     .byte   0
; CHECK-NEXT:     #RegNums: 0
; CHECK-NEXT:     #SlotsNums: 1
; CHECK-NEXT:             #Idx[0]: BaseOffset: -24, SlotBits: 0x1[ -24 ]

entry:
  %r = alloca %record, align 8
  %r.cast = bitcast %record* %r to i8*
  %var = addrspacecast %record* %r to %record addrspace(1)*
  br label %body

body:                                             ; preds = %entry
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @cj_stack_grow, i32 0, i32 0)
  call void @llvm.lifetime.start.p0i8(i64 16, i8* %r.cast)
  call void @llvm.memset.p0i8.i64(i8* nonnull align 8 %r.cast, i8 0, i64 16, i1 false)
  %token1 = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (i8 addrspace(1)*, %record addrspace(1)*)* @test, i32 2, i32 0, i8 addrspace(1)* null, %record addrspace(1)* %var) [ "struct-live"(%record* %r) ]
  ret i64 0
}

; Function Attrs: argmemonly nocallback nofree nounwind willreturn writeonly
declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg) #1

; Function Attrs: argmemonly nocallback nofree nosync nounwind willreturn
declare void @llvm.lifetime.start.p0i8(i64 immarg, i8* nocapture) #2

declare token @llvm.cj.gc.statepoint(...)

attributes #0 = { "hasRcdParam" }
attributes #1 = { argmemonly nocallback nofree nounwind willreturn writeonly }
attributes #2 = { argmemonly nocallback nofree nosync nounwind willreturn }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"HasRewrittenStatepoint", i32 1}
