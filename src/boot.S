#include "mm.h"

.section ".text.boot"
.globl _start

_start:
    // read core id from multiprocessor affinity register
    mrs    x0, mpidr_el1
    and    x0, x0, #0xFF        // x0 = core id (0, 1, 2 or 3)

    // separate stack for each core: sp = LOW_MEMORY - (core id * 64KB)
    mov    x1, #0x10000
    mul    x1, x0, x1
    mov    x2, #LOW_MEMORY
    sub    x2, x2, x1
    mov    sp, x2

    // secondary cores go straight to the kernel
    cbnz   x0, secondary

    // core 0 only: clear bss (before anybody uses global variables)
    adr    x0, bss_begin
    adr    x1, bss_end
    sub    x1, x1, x0
    bl     memzero

    // core 0 only: release cores 1, 2, 3 (spin table of the firmware / qemu)
    adr    x1, _start
    mov    x2, #0xE0            // core 1 release address
    str    x1, [x2]
    mov    x2, #0xE8            // core 2 release address
    str    x1, [x2]
    mov    x2, #0xF0            // core 3 release address
    str    x1, [x2]
    dsb    sy
    sev                         // wake up the parked cores

    mov    x0, #0               // core id 0
    bl     kernel_main
    b      halt

secondary:
    // core id is still in x0
    bl     kernel_main

halt:
    wfe
    b      halt
