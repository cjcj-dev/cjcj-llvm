; RUN: opt < %s '-passes=cj-pea' -S | FileCheck %s
;
; UncolorIfGCPtr emits inttoptr(and(ptrtoint(P), AddressMask)) still in
; addrspace(1).  PEA must look through that chain so a gcwrite of the peeled
; value still counts as an escape of the original NewObject.  Without it,
; PEA stack-promotes NewObject and a coloured stack address is stored into
; the heap array (startupcolour sigSlot / peallvm).
;
; CHECK-LABEL: @store_uncoloured(
; CHECK: call {{.*}} @CJ_MCC_NewObject
; CHECK-NOT: alloca { %TypeInfo*, %ObjLayout._ZN7default5HumanE }

%BitMap = type { i32, [0 x i8] }
%ObjLayout._ZN7default5HumanE = type { i8 addrspace(1)* }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }

@"std.core$Object.ti" = external global %TypeInfo
@_ZN7default5HumanE.ti = weak_odr global %TypeInfo {i8* getelementptr inbounds ([14 x i8], [14 x i8]* @"default$Human.name", i32 0, i32 0), i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$Human.ti.offsets", i32 0, i32 0), i8* null, i8* null, i8* bitcast ([1 x %TypeInfo*]* @"default$Human.ti.fields" to i8*), %TypeInfo* @"std.core$Object.ti", i8* null, i8* bitcast ([1 x i8*]* @"default$Human.fieldNames" to i8*)}, !RelatedType !0
@"default$Human.name" = internal global [14 x i8] c"default$Human\00", align 1
@"default$Human.ti.offsets" = internal global [1 x i32] [i32 0]
@"default$Human.ti.fields" = internal global [1 x %TypeInfo*] [%TypeInfo* @"std.core$Object.ti"]
@"default$Human.fieldNames" = internal global [1 x i8*] [i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"default$Human.field.1.name", i32 0, i32 0)]
@"default$Human.field.1.name" = internal global [3 x i8] c"aa\00", align 1

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @use(i8 addrspace(1)*)

define void @store_uncoloured(i8 addrspace(1)* %arr) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default5HumanE.ti to i8*), i32 16)
  ; UncolorIfGCPtr sequence (AddressMask = (1<<48)-1)
  %asint = ptrtoint i8 addrspace(1)* %obj to i64
  %masked = and i64 %asint, 281474976710655
  %plain = inttoptr i64 %masked to i8 addrspace(1)*
  %slot = getelementptr inbounds i8, i8 addrspace(1)* %arr, i64 16
  %slot.p = bitcast i8 addrspace(1)* %slot to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %plain, i8 addrspace(1)* %arr, i8 addrspace(1)* addrspace(1)* %slot.p)
  call void @use(i8 addrspace(1)* %arr)
  ret void
}

!0 = !{!"ObjLayout._ZN7default5HumanE"}
