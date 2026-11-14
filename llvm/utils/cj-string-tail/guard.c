// Deterministic machine-code consumer of the direct LLVM legality regression.
#include <stdbool.h>
#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
extern uint64_t unknown_extent(unsigned char *, uint64_t, bool *, uint64_t);
extern uint64_t in_range(unsigned char *, uint64_t, bool *, uint64_t);
int main(void) {
  long size = sysconf(_SC_PAGESIZE);
  if (size <= 0) return 10;
  unsigned char *p = mmap(0, (size_t)size * 2, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (p == MAP_FAILED) return 11;
  if (mprotect(p + size, size, PROT_NONE)) return 12;
  bool skip = false, run = true;
  uint64_t control = in_range(p, 0, &run, 1);
  if (control != 0) return 13;
  uint64_t result = unknown_extent(p, size, &skip, 1);
  if (result != 0) return 14;
  if (munmap(p, (size_t)size * 2)) return 15;
  puts("GUARD_CONTROL_AND_BOUNDARY_OK");
  return 0;
}
