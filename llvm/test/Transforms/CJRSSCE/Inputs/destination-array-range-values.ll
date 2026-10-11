declare i32 @printf(i8*, ...)
@driver_msg0 = private constant [58 x i8] c"source_changed_between_copies(): actual=%lld expected=11\0A\00"
@driver_msg1 = private constant [57 x i8] c"candidate_destination_changed(): actual=%lld expected=3\0A\00"
@driver_msg2 = private constant [56 x i8] c"current_destination_changed(): actual=%lld expected=11\0A\00"
@driver_msg3 = private constant [50 x i8] c"unchanged_array_copies(): actual=%lld expected=3\0A\00"
define i32 @main() {
  %value0 = call i64 @source_changed_between_copies()
  %print0 = call i32 (i8*, ...) @printf(i8* getelementptr ([58 x i8], [58 x i8]* @driver_msg0, i64 0, i64 0), i64 %value0)
  %bad0 = icmp ne i64 %value0, 11
  %rc0 = zext i1 %bad0 to i32
  %value1 = call i64 @candidate_destination_changed()
  %print1 = call i32 (i8*, ...) @printf(i8* getelementptr ([57 x i8], [57 x i8]* @driver_msg1, i64 0, i64 0), i64 %value1)
  %bad1 = icmp ne i64 %value1, 3
  %rc1 = zext i1 %bad1 to i32
  %value2 = call i64 @current_destination_changed()
  %print2 = call i32 (i8*, ...) @printf(i8* getelementptr ([56 x i8], [56 x i8]* @driver_msg2, i64 0, i64 0), i64 %value2)
  %bad2 = icmp ne i64 %value2, 11
  %rc2 = zext i1 %bad2 to i32
  %value3 = call i64 @unchanged_array_copies()
  %print3 = call i32 (i8*, ...) @printf(i8* getelementptr ([50 x i8], [50 x i8]* @driver_msg3, i64 0, i64 0), i64 %value3)
  %bad3 = icmp ne i64 %value3, 3
  %rc3 = zext i1 %bad3 to i32
  %sum1 = add i32 %rc0, %rc1
  %sum2 = add i32 %sum1, %rc2
  %sum3 = add i32 %sum2, %rc3
  ret i32 %sum3
}
