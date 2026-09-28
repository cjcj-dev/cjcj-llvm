; RUN: opt -passes=cj-simple-opt -S < %s | FileCheck %s
; Only the actual runtime length slot may fold to the allocation's length.
; CHECK-LABEL: define i64 @length_slot(
; CHECK: ret i64 3
; CHECK-LABEL: define i64 @payload_slot(
; CHECK: ret i64 %value

define i64 @length_slot(i8* %ti) {
  %array = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* %ti, i64 3, i64 40)
  %slot = getelementptr i8, i8 addrspace(1)* %array, i64 8
  %typed = bitcast i8 addrspace(1)* %slot to i64 addrspace(1)*
  %value = load i64, i64 addrspace(1)* %typed
  ret i64 %value
}
define i64 @payload_slot(i8* %ti) {
  %array = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* %ti, i64 3, i64 40)
  %slot = getelementptr i8, i8 addrspace(1)* %array, i64 16
  %typed = bitcast i8 addrspace(1)* %slot to i64 addrspace(1)*
  %value = load i64, i64 addrspace(1)* %typed
  ret i64 %value
}
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
