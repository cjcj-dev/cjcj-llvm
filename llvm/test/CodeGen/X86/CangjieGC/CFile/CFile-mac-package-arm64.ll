; REQUIRES: aarch64-registered-target
; RUN: not not llc -mtriple=arm64-apple-darwin --cangjie-pipeline < %s -o /dev/null 2>&1 | FileCheck %s --check-prefixes=ARM

%Unit.Type = type { i8 }
%record._ZN8std.core6StringE = type { %record._ZN8std.core5ArrayIhE, i64 }
%record._ZN8std.core5ArrayIhE = type { i8 addrspace(1)*, i64, i64 }
%KlassInfo.0 = type { i32, i32, %BitMap*, %KlassInfo.0*, i8**, i64*, i64*, i8*, i64*, i32, [0 x %KlassInfo.0*] }
%BitMap = type { i32, [0 x i8] }
%KlassInfo.1 = type { i32, i32, %BitMap*, %KlassInfo.0*, i8**, i64*, i64*, i8*, i64*, i32, [1 x %KlassInfo.0*] }

@"$const_cjstring.4RCxJdy1D-V" = internal constant { { i8 addrspace(1)*, i64, i64 }, i64 } { { i8 addrspace(1)*, i64, i64 } { i8 addrspace(1)* addrspacecast (i8* bitcast ({ i8*, i64, [54 x i8] }* @"$const_cjstring_data.2kj5CN6GcdE" to i8*) to i8 addrspace(1)*), i64 0, i64 11 }, i64 0 }
@"$const_cjstring_data.2kj5CN6GcdE" = internal constant { i8*, i64, [54 x i8] } { i8* bitcast (%KlassInfo.0* @roUInt8.arrayKlass to i8*), i64 54, [54 x i8] c"hello worldAn exception has occurred:    Out of memory" }
@roUInt8.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 1, %BitMap* null, %KlassInfo.0* @array_int8.primKlass, i8** null, i64* null, i64* null, i8* null, i64* null, i32 0, [0 x %KlassInfo.0*] zeroinitializer }, no_sanitize_address
@array_int8.primKlass = weak_odr hidden global %KlassInfo.0 { i32 1, i32 1, %BitMap* null, %KlassInfo.0* null, i8** null, i64* null, i64* null, i8* null, i64* @array_int8.uniqueAddr, i32 0, [0 x %KlassInfo.0*] zeroinitializer }, no_sanitize_address
@array_int8.uniqueAddr = weak_odr hidden global i64 0

declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_MCC_StackCheck()
declare cangjiegccc void @MCC_SafepointStub() local_unnamed_addr
declare void @_ZN8std.core7printlnER_ZN8std.core6StringE(%Unit.Type* sret(%Unit.Type), i8*, %record._ZN8std.core6StringE*) local_unnamed_addr gc "cangjie"

; ARM: LLVM ERROR: There is not cangjie package id in module!
; ARM: Aborted

define i64 @"_ZN7default6<main>Ev"() gc "cangjie" personality i32 (...)* @"__cj_personality_v0$" {
bb0:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 4, i32 0, void ()* @CJ_MCC_StackCheck, i32 0, i32 0)
  %0 = alloca %Unit.Type, align 8
  %token2 = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 3, i32 0, void ()* @MCC_SafepointStub, i32 0, i32 0)
  %token4 = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (%Unit.Type*, i8*, %record._ZN8std.core6StringE*)* @_ZN8std.core7printlnER_ZN8std.core6StringE, i32 3, i32 0, %Unit.Type* sret(%Unit.Type) %0, i8* null, %record._ZN8std.core6StringE* bitcast ({ { i8 addrspace(1)*, i64, i64 }, i64 }* @"$const_cjstring.4RCxJdy1D-V" to %record._ZN8std.core6StringE*))
  ret i64 0
}

define private i32 @"__cj_personality_v0$"(...) {
entry:
  ret i32 0
}
