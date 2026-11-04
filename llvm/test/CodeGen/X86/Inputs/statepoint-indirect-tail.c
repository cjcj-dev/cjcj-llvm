#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
static volatile unsigned calls;
static volatile uint64_t sum;
void clobber(void) {
  __asm__ volatile("" ::: "rax", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory");
}
void expected(uint64_t a,uint64_t b,uint64_t c,uint64_t d,uint64_t e,uint64_t f) { ++calls; sum=a+3*b+5*c+7*d+11*e+13*f; }
void direct_callee(void) { ++calls; }
extern void direct_control(void);
extern int check_saved(void);
extern uint64_t c15_tls[64];
__attribute__((noreturn)) void CJ_MCC_HandleReturnSafepoint(void) {
  fputs("UNEXPECTED_RETURN_POLL_SLOW_PATH\n", stderr);
  abort();
}
int main(int argc, char **argv) {
  (void)argv;
  if (argc > 1) for (unsigned i=0; i<64; ++i) c15_tls[i]=0;
  int saved=check_saved();
  if (saved || calls!=1 || sum!=183) { fprintf(stderr,"TARGET_OR_CALLEE_SAVE_FAIL saved=%d calls=%u sum=%llu\n", saved,calls,(unsigned long long)sum); return 1; }
  direct_control();
  if (calls!=2) return 2;
  puts("TARGET_AND_CALLEE_SAVE_PASS calls=2 sum=183 registers=RBX,RBP,R12,R13,R14,R15");
  return 0;
}
