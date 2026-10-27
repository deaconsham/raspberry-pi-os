/*
 * void memzero(void *addr, size_t size)
 *
 * x0 - start address, 8-byte aligned
 * x1 - size in bytes, multiple of 8
 *
 * Zeroes memory; boot.S uses it to clear bss. The loop stores before it checks,
 * so it always clears at least 8 bytes (even when size is 0) and overshoots if size isn't a multiple of 8.
 */
.globl memzero
memzero:
    str    xzr, [x0], #8        // *x0 = 0, x0 += 8
    subs   x1, x1, #8           // size -= 8, set flags
    b.gt   memzero              // loop while size > 0
    ret
