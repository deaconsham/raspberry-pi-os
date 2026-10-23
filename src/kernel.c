#include "uart.h"
#include "utils.h"
#include <stdint.h>

// set to 1 by core 0 when the uart is ready, other cores wait for it
volatile int uart_ready = 0;

struct message {
    char text[32];
} __attribute__((aligned(16)));

static const struct message hello = { "Hello, from processor " };

void kernel_main(uint64_t core_id)
{
    if (core_id == 0) {
        // uart is initialized only once, by core 0
        uart_init();
        uart_ready = 1;
    } else {
        while (uart_ready == 0) {}
    }

    // stagger the cores so their output does not interleave
    // (delay(0) would underflow and loop forever, so core 0 skips it)
    if (core_id != 0) {
        delay(core_id * 2000000);
    }

    // the greeting is copied as a whole 32-byte, 16-byte aligned struct on
    // purpose: gcc does that with ldp/stp of q0/q1 (FP/SIMD registers)
    // unless -mgeneral-regs-only is used
    struct message greeting = hello;
    uart_send_string(greeting.text);
    uart_send(core_id + '0');
    uart_send_string("\r\n");

    // park the core
    while (1) {}
}
