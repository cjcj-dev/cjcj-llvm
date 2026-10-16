declare i32 @printf(i8*, ...)
@driver_msg0 = private constant [41 x i8] c"candidate_gap(): actual=%lld expected=2\0A\00"
@driver_msg1 = private constant [51 x i8] c"candidate_shift_changes(): actual=%lld expected=2\0A\00"
@driver_msg2 = private constant [48 x i8] c"candidate_contiguous(): actual=%lld expected=2\0A\00"
@driver_msg3 = private constant [52 x i8] c"candidate_shifted_window(): actual=%lld expected=2\0A\00"
define i32 @main() {
  %value0 = call i64 @candidate_gap()
  %print0 = call i32 (i8*, ...) @printf(i8* getelementptr ([41 x i8], [41 x i8]* @driver_msg0, i64 0, i64 0), i64 %value0)
  %bad0 = icmp ne i64 %value0, 2
  %rc0 = zext i1 %bad0 to i32
  %value1 = call i64 @candidate_shift_changes()
  %print1 = call i32 (i8*, ...) @printf(i8* getelementptr ([51 x i8], [51 x i8]* @driver_msg1, i64 0, i64 0), i64 %value1)
  %bad1 = icmp ne i64 %value1, 2
  %rc1 = zext i1 %bad1 to i32
  %value2 = call i64 @candidate_contiguous()
  %print2 = call i32 (i8*, ...) @printf(i8* getelementptr ([48 x i8], [48 x i8]* @driver_msg2, i64 0, i64 0), i64 %value2)
  %bad2 = icmp ne i64 %value2, 2
  %rc2 = zext i1 %bad2 to i32
  %value3 = call i64 @candidate_shifted_window()
  %print3 = call i32 (i8*, ...) @printf(i8* getelementptr ([52 x i8], [52 x i8]* @driver_msg3, i64 0, i64 0), i64 %value3)
  %bad3 = icmp ne i64 %value3, 2
  %rc3 = zext i1 %bad3 to i32
  %sum1 = add i32 %rc0, %rc1
  %sum2 = add i32 %sum1, %rc2
  %sum3 = add i32 %sum2, %rc3
  ret i32 %sum3
}
