declare i32 @printf(i8*, ...)
@value_msg0 = private constant [50 x i8] c"read_across_phi(i1 true): actual=%lld expected=2\0A\00"
@value_msg1 = private constant [51 x i8] c"read_across_phi(i1 false): actual=%lld expected=1\0A\00"
@value_msg2 = private constant [59 x i8] c"read_across_phi_no_write(i1 true): actual=%lld expected=1\0A\00"
@value_msg3 = private constant [60 x i8] c"read_across_phi_no_write(i1 false): actual=%lld expected=1\0A\00"
@value_msg4 = private constant [59 x i8] c"same_snapshot_across_phi(i1 true): actual=%lld expected=1\0A\00"
@value_msg5 = private constant [60 x i8] c"same_snapshot_across_phi(i1 false): actual=%lld expected=1\0A\00"
define i32 @main() {
  %value0 = call i64 @read_across_phi(i1 true)
  %print0 = call i32 (i8*, ...) @printf(i8* getelementptr ([50 x i8], [50 x i8]* @value_msg0, i64 0, i64 0), i64 %value0)
  %bad0 = icmp ne i64 %value0, 2
  %rc0 = zext i1 %bad0 to i32
  %value1 = call i64 @read_across_phi(i1 false)
  %print1 = call i32 (i8*, ...) @printf(i8* getelementptr ([51 x i8], [51 x i8]* @value_msg1, i64 0, i64 0), i64 %value1)
  %bad1 = icmp ne i64 %value1, 1
  %rc1 = zext i1 %bad1 to i32
  %value2 = call i64 @read_across_phi_no_write(i1 true)
  %print2 = call i32 (i8*, ...) @printf(i8* getelementptr ([59 x i8], [59 x i8]* @value_msg2, i64 0, i64 0), i64 %value2)
  %bad2 = icmp ne i64 %value2, 1
  %rc2 = zext i1 %bad2 to i32
  %value3 = call i64 @read_across_phi_no_write(i1 false)
  %print3 = call i32 (i8*, ...) @printf(i8* getelementptr ([60 x i8], [60 x i8]* @value_msg3, i64 0, i64 0), i64 %value3)
  %bad3 = icmp ne i64 %value3, 1
  %rc3 = zext i1 %bad3 to i32
  %value4 = call i64 @same_snapshot_across_phi(i1 true)
  %print4 = call i32 (i8*, ...) @printf(i8* getelementptr ([59 x i8], [59 x i8]* @value_msg4, i64 0, i64 0), i64 %value4)
  %bad4 = icmp ne i64 %value4, 1
  %rc4 = zext i1 %bad4 to i32
  %value5 = call i64 @same_snapshot_across_phi(i1 false)
  %print5 = call i32 (i8*, ...) @printf(i8* getelementptr ([60 x i8], [60 x i8]* @value_msg5, i64 0, i64 0), i64 %value5)
  %bad5 = icmp ne i64 %value5, 1
  %rc5 = zext i1 %bad5 to i32
  %sum1 = add i32 %rc0, %rc1
  %sum2 = add i32 %sum1, %rc2
  %sum3 = add i32 %sum2, %rc3
  %sum4 = add i32 %sum3, %rc4
  %sum5 = add i32 %sum4, %rc5
  ret i32 %sum5
}
