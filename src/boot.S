#include "mm.h"
#include "arm/sysregs.h"

#ifndef CPACR_VALUE
#define CPACR_VALUE CPACR_FPEN_NO_TRAP
#endif

.section ".text.boot"
.globl _start

/*
 *  - Exception levels (EL0-EL3) are CPU privilege levels, higher = more power:
 *    EL3 = firmware, EL2 = hypervisor, EL1 = kernel (us), EL0 = user code.
 *  - The CPU only drops a level by returning from an exception, so we fake one: 
 *    set spsr_elX (state to return to) and elr_elX (address to return to), then eret.
 *  - bss holds uninitialized globals. It takes no space in kernel8.img,
 *    so nobody zeroes it for us; we do it below.
 *  - Calling convention: arguments go in x0, x1, ...; bl saves the return address in x30 (the link register) and ret jumps back to it.
 */

/*
 * Entry point for every core: core 0, and cores 1-3 once released from the spin table.
 * The firmware leaves us at:
 *   - EL3 on real hardware (old firmware)
 *   - EL2 on qemu raspi3b with -kernel (no EL3 firmware is emulated)
 * Each core then steps down to EL1.
 */
_start:
    mrs    x0, CurrentEL
    lsr    x0, x0, #2           // EL is in bits [3:2]
    cmp    x0, #3
    b.eq   el3_entry
    cmp    x0, #2
    b.eq   el2_entry
    b      el1_entry            // already at EL1

/*
 * EL3 to EL2. Only reached when entering at EL3: EL3 registers can't be accessed from EL2 (msr scr_el3 traps on qemu).
 *
 * ldr xN, =CONST loads a constant too large for mov from a nearby literal pool.
 */
el3_entry:
    ldr    x0, =SCR_VALUE       // EL2 non-secure, AArch64 below EL3
    msr    scr_el3, x0
    ldr    x0, =CPTR_EL3_VALUE  // no FP/SIMD traps to EL3
    msr    cptr_el3, x0
    ldr    x0, =SPSR_EL3_VALUE  // EL2h, interrupts masked
    msr    spsr_el3, x0
    adr    x0, el2_entry        // PC-relative label address
    msr    elr_el3, x0          // return address
    eret

/*
 * EL2 -> EL1.
 */
el2_entry:
    ldr    x0, =SCTLR_VALUE_MMU_DISABLED
    msr    sctlr_el1, x0        // EL1: MMU and caches off
    ldr    x0, =HCR_VALUE       // EL1 is AArch64
    msr    hcr_el2, x0
    ldr    x0, =CPTR_EL2_VALUE  // no FP/SIMD traps to EL2
    msr    cptr_el2, x0
    ldr    x0, =SPSR_EL2_VALUE  // EL1h, interrupts masked
    msr    spsr_el2, x0
    adr    x0, el1_entry
    msr    elr_el2, x0          // return address
    eret

/*
 * EL1: per-core setup, then core 0 clears bss and releases cores 1-3.
 */
el1_entry:
    // enable FP/SIMD at EL1/EL0, otherwise the FP/SIMD instructions gcc
    // emits would trap (and hang, since no vector table is installed)
    ldr    x0, =CPACR_VALUE
    msr    cpacr_el1, x0
    isb                         // sync the system register write

    mrs    x0, mpidr_el1        // multiprocessor affinity register
    and    x0, x0, #0xFF        // x0 = core id (0-3)

    // cores run concurrently, so each gets its own 64KB stack:
    // sp = LOW_MEMORY - id * 64KB (stacks grow down from the slot's top)
    mov    x1, #0x10000
    mul    x1, x0, x1
    mov    x2, #LOW_MEMORY
    sub    x2, x2, x1
    mov    sp, x2

    cbnz   x0, secondary        // cores 1-3 skip core 0's setup

    // core 0: zero bss (bss_begin/bss_end come from linker.ld)
    adr    x0, bss_begin        // arg 1: start
    adr    x1, bss_end
    sub    x1, x1, x0           // arg 2: size
    bl     memzero

    // core 0: release cores 1-3. each parked core polls its 8-byte slot and jumps to the address there once it is non-zero
    adr    x1, _start
    mov    x2, #0xE0            // core 1 slot
    str    x1, [x2]
    mov    x2, #0xE8            // core 2 slot
    str    x1, [x2]
    mov    x2, #0xF0            // core 3 slot
    str    x1, [x2]
    dsb    sy                   // wait for the stores to finish
    sev                         // wake the parked cores

    mov    x0, #0               // arg 1: core id
    bl     kernel_main
    b      halt                 // kernel_main shouldn't return

secondary:
    bl     kernel_main          // arg 1: core id (already in x0)

halt:
    wfe                         // low-power wait for an event
    b      halt
