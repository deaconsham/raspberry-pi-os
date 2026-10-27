/*
 * Memory-mapped I/O helpers.
 *
 * Peripheral registers (UART, GPIO, ...) live at fixed addresses;
 * accessing those addresses talks to the hardware instead of RAM.
 * Registers are 32-bit, so values use w registers and addresses use x registers.
 */

/*
 * void put32(uint64_t addr, uint32_t value)
 *
 * x0 - register address
 * w1 - value to write
 */
.globl put32
put32:
    str    w1, [x0]
    ret

/*
 * uint32_t get32(uint64_t addr)
 *
 * x0 - register address
 * w0 - returns the value read
 */
.globl get32
get32:
    ldr    w0, [x0]
    ret

/*
 * void delay(uint64_t count)
 *
 * x0 - iterations to spin
 *
 * Crude busy-wait for GPIO settle time (uart.c) and core staggering (kernel.c). delay(0) underflows and spins (almost) forever.
 */
.globl delay
delay:
    subs   x0, x0, #1           // count -= 1, set flags
    bne    delay                // loop until count == 0
    ret
