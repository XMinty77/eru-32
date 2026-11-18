# Startup code: set up sp and gp, zero .bss, call main,
# then store main's return value to the exit address and wait.

    .section .text.start, "ax"
    .globl _start
_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop
    la      sp, __stack_top

    # Zero .bss, a word at a time (the linker script aligns both ends to 4).
    la      t0, __bss_start
    la      t1, __bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    main

    # Exit code: main's return value.
    li      t0, 0x80000000
    sw      a0, 0(t0)
3:  j       3b
