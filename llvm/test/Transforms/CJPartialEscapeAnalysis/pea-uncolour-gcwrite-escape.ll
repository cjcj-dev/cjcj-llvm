; RUN: opt < %s '-passes=cj-pea' -S | FileCheck %s
;
; UncolorIfGCPtr emits inttoptr(and(ptrtoint(P), AddressMask)) still in
; addrspace(1).  PEA must look through that chain so a gcwrite of the peeled
; value still counts as an escape of the original NewObject.  Without it,
; PEA stack-promotes NewObject and a coloured stack address is stored into
; the heap array (startupcolour sigSlot / peallvm).
;
; CHECK-NOT: alloca { %TypeInfo*, %ObjLayout.Obj }

%BitMap = type { i32, [0 x i8] }
%TypeTemplate = type { i8*, i8, i8, i16, i16, i8*, i8*, i8*, i8* }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%ArrayBase = type { i64 }
%ArrayLayout.refArray = type { %ArrayBase, [0 x i8 addrspace(1)*] }
%ObjLayout.Obj = type { i64 }

@"std.core$Object.ti" = external global %TypeInfo
@_ZN7default3ObjE.ti = internal global %TypeInfo { i8* getelementptr inbounds ([12 x i8], [12 x i8]* @"default$Obj.name", i32 0, i32 0), i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$Obj.ti.offsets", i32 0, i32 0), i8* null, i8* null, i8* bitcast ([1 x %TypeInfo*]* @"default$Obj.ti.fields" to i8*), %TypeInfo* @"std.core$Object.ti", i8* null, i8* bitcast ([1 x i8*]* @"default$Obj.fieldNames" to i8*) }, !RelatedType !1
@"default$Obj.name" = internal global [12 x i8] c"default$Obj\00", align 1
@"default$Obj.ti.offsets" = internal global [1 x i32] [i32 0]
@"default$Obj.ti.fields" = internal global [1 x %TypeInfo*] [%TypeInfo* @"std.core$Object.ti"]
@"default$Obj.fieldNames" = internal global [1 x i8*] [i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"default$Obj.field.1.name", i32 0, i32 0)]
@"default$Obj.field.1.name" = internal global [3 x i8] c"aa\00", align 1
@"RawArray<Obj>.ti" = internal global %TypeInfo { i8* getelementptr inbounds ([14 x i8], [14 x i8]* @"RawArray<Obj>.name", i32 0, i32 0), i8 -126, i8 0, i16 0, i32 8, %BitMap* null, i32 0, i8 8, i8 0, i32* null, i8* bitcast (%TypeTemplate* @RawArray.tt to i8*), i8* null, i8* null, %TypeInfo* @"std.core$Object.ti", i8* null, i8* null }, !RelatedType !0
@"RawArray<Obj>.name" = internal global [14 x i8] c"RawArray<Obj>\00"
@RawArray.tt = external global %TypeTemplate

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @use(i8 addrspace(1)*)

; CHECK-LABEL: @store_uncoloured_new_into_heap_array(
; CHECK: call {{.*}} @CJ_MCC_NewObject
; CHECK: call {{.*}} @CJ_MCC_NewArray
; CHECK-NOT: alloca { %TypeInfo*, %ObjLayout.Obj }
define void @store_uncoloured_new_into_heap_array() gc "cangjie" {
entry:
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default3ObjE.ti to i8*), i32 16)
  ; UncolorIfGCPtr sequence (AddressMask = (1<<48)-1)
  %asint = ptrtoint i8 addrspace(1)* %obj to i64
  %masked = and i64 %asint, 281474976710655
  %plain = inttoptr i64 %masked to i8 addrspace(1)*
  %arr = call noalias i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Obj>.ti" to i8*), i64 4)
  %slot = getelementptr inbounds i8, i8 addrspace(1)* %arr, i64 16
  %slot.p = bitcast i8 addrspace(1)* %slot to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %plain, i8 addrspace(1)* %arr, i8 addrspace(1)* addrspace(1)* %slot.p)
  call void @use(i8 addrspace(1)* %arr)
  ret void
}

!0 = !{!"RawArray<Obj>"}
!1 = !{!"ObjLayout.Obj"}
