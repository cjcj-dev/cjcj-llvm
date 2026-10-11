declare i32 @printf(i8*, ...)
@extent_msg0 = private constant [61 x i8] c"partial_array_source_propagation(): actual=%lld expected=15\0A\00"
@extent_msg1 = private constant [58 x i8] c"full_array_source_propagation(): actual=%lld expected=15\0A\00"
@extent_msg2 = private constant [54 x i8] c"full_array_source_changed(): actual=%lld expected=15\0A\00"
@extent_msg3 = private constant [66 x i8] c"partial_array_destination_propagation(): actual=%lld expected=15\0A\00"
define i32 @main() {
  %value0 = call i64 @partial_array_source_propagation()
  %print0 = call i32 (i8*, ...) @printf(i8* getelementptr ([61 x i8], [61 x i8]* @extent_msg0, i64 0, i64 0), i64 %value0)
  %bad0 = icmp ne i64 %value0, 15
  %rc0 = zext i1 %bad0 to i32
  %value1 = call i64 @full_array_source_propagation()
  %print1 = call i32 (i8*, ...) @printf(i8* getelementptr ([58 x i8], [58 x i8]* @extent_msg1, i64 0, i64 0), i64 %value1)
  %bad1 = icmp ne i64 %value1, 15
  %rc1 = zext i1 %bad1 to i32
  %value2 = call i64 @full_array_source_changed()
  %print2 = call i32 (i8*, ...) @printf(i8* getelementptr ([54 x i8], [54 x i8]* @extent_msg2, i64 0, i64 0), i64 %value2)
  %bad2 = icmp ne i64 %value2, 15
  %rc2 = zext i1 %bad2 to i32
  %value3 = call i64 @partial_array_destination_propagation()
  %print3 = call i32 (i8*, ...) @printf(i8* getelementptr ([66 x i8], [66 x i8]* @extent_msg3, i64 0, i64 0), i64 %value3)
  %bad3 = icmp ne i64 %value3, 15
  %rc3 = zext i1 %bad3 to i32
  %sum1 = add i32 %rc0, %rc1
  %sum2 = add i32 %sum1, %rc2
  %sum3 = add i32 %sum2, %rc3
  ret i32 %sum3
}
