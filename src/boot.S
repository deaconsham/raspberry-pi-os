#include "mm.h"
#include "arm/sysregs.h"

#ifndef CPACR_VALUE
#define CPACR_VALUE CPACR_FPEN_NO_TRAP
#endif

.section ".text.boot"
.globl _start

// every core (the primary one and the ones released from the spin table)
// enters here at whatever exception level the firmware/qemu left it in:
//   - real hardware with old firmware: EL3
//   - qemu raspi3b (-kernel):          EL2 (qemu emulates no EL3 firmware)
// and is walked down EL3 -> EL2 -> EL1 (the entry levels above are skipped)
_start:
    mrs    x0, CurrentEL
    lsr    x0, x0, #2           // EL is in bits [3:2]
    cmp    x0, #3
    b.eq   el3_entry
    cmp    x0, #2
    b.eq   el2_entry
    b      el1_entry            // already at EL1

el3_entry:
    // EL3 registers are not accessible from EL2 (msr scr_el3 would trap on qemu)
    // that is why this part is skipped when started at EL2
    ldr    x0, =SCR_VALUE       // EL2 is non-secure, aarch64 below EL3
    msr    scr_el3, x0
    ldr    x0, =CPTR_EL3_VALUE  // do not trap FP/SIMD accesses to EL3
    msr    cptr_el3, x0
    ldr    x0, =SPSR_EL3_VALUE  // return to EL2h with interrupts masked
    msr    spsr_el3, x0
    adr    x0, el2_entry
    msr    elr_el3, x0
    eret

el2_entry:
    ldr    x0, =SCTLR_VALUE_MMU_DISABLED
    msr    sctlr_el1, x0        // EL1 starts with the MMU and caches off
    ldr    x0, =HCR_VALUE       // EL1 runs in aarch64 mode
    msr    hcr_el2, x0
    ldr    x0, =CPTR_EL2_VALUE  // do not trap FP/SIMD accesses to EL2
    msr    cptr_el2, x0
    ldr    x0, =SPSR_EL2_VALUE  // return to EL1h with interrupts masked
    msr    spsr_el2, x0
    adr    x0, el1_entry
    msr    elr_el2, x0
    eret

el1_entry:
    // allow FP/SIMD at EL1 and EL0, otherwise the first FP/SIMD instruction
    // emitted by gcc traps (and, with no vector table installed, hangs)
    ldr    x0, =CPACR_VALUE
    msr    cpacr_el1, x0
    isb

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
