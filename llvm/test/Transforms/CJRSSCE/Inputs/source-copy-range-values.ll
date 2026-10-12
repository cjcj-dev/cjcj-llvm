declare i32 @printf(ptr, ...)
@value_msg0 = private constant [50 x i8] c"second_element_changed(): actual=%lld expected=3\0A\00"
@value_msg1 = private constant [48 x i8] c"second_element_clean(): actual=%lld expected=3\0A\00"
@value_msg2 = private constant [57 x i8] c"second_element_disjoint_write(): actual=%lld expected=3\0A\00"
define i32 @main() {
  %value0 = call i64 @second_element_changed()
  %print0 = call i32 (ptr, ...) @printf(ptr @value_msg0, i64 %value0)
  %bad0 = icmp ne i64 %value0, 3
  %rc0 = zext i1 %bad0 to i32
  %value1 = call i64 @second_element_clean()
  %print1 = call i32 (ptr, ...) @printf(ptr @value_msg1, i64 %value1)
  %bad1 = icmp ne i64 %value1, 3
  %rc1 = zext i1 %bad1 to i32
  %value2 = call i64 @second_element_disjoint_write()
  %print2 = call i32 (ptr, ...) @printf(ptr @value_msg2, i64 %value2)
  %bad2 = icmp ne i64 %value2, 3
  %rc2 = zext i1 %bad2 to i32
  %sum1 = add i32 %rc0, %rc1
  %sum2 = add i32 %sum1, %rc2
  ret i32 %sum2
}
