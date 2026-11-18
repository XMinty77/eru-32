// Helpers for programs running on eru-32 in the core bench (tb/core/core_tb.sv).
#ifndef ERU_H
#define ERU_H

#include <stdint.h>

// Memory-mapped outputs (stores only).
#define ERU_EXIT_ADDR 0x80000000u  // store the exit code: 0 = PASS, anything else = FAIL
#define ERU_PUTC_ADDR 0x80000004u  // store a character to print

#define ERU_MMIO(addr) (*(volatile uint32_t *)(addr))

static inline void putchar(int c) { ERU_MMIO(ERU_PUTC_ADDR) = (uint32_t)c; }

static inline void puts(const char *s) {
  while (*s) putchar(*s++);
  putchar('\n');
}

// Print a word as 8 hex digits, no prefix or newline.
static inline void print_hex(uint32_t x) {
  for (int i = 28; i >= 0; i -= 4) putchar("0123456789abcdef"[(x >> i) & 0xf]);
}

static inline void print_dec(uint32_t x) {
  char buf[10];            // uint32_t max is 4294967295, which is 10 digits
  char *p = buf + sizeof buf;
  
  do {
    *--p = "0123456789"[x % 10];
    x /= 10;
  } while (x > 0);

  while (p < buf + sizeof buf) putchar(*p++);
}

// End the run now with an exit code (returning from main does the same).
static inline __attribute__((noreturn)) void exit(int code) {
  ERU_MMIO(ERU_EXIT_ADDR) = (uint32_t)code;
  for (;;) {}
}

#endif
