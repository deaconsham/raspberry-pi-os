#include "utils.h"
#include "peripherals/uart.h"
#include "peripherals/gpio.h"

void uart_init (void)
{
    unsigned int selector;

    // configure gpio14 and gpio15 for pl011 (alt fcn 0)
    selector = get32(GPFSEL1);
    selector &= ~(7<<12);                   // clean gpio14
    selector |= 4<<12;                      // set alt0 for gpio14
    selector &= ~(7<<15);                   // clean gpio15
    selector |= 4<<15;                      // set alt0 for gpio15
    put32(GPFSEL1,selector);

    // clear pull-up/pull-down control for gpio14/gpio15
    put32(GPPUD,0);
    delay(150);
    put32(GPPUDCLK0,(1<<14)|(1<<15));
    delay(150);
    put32(GPPUDCLK0,0);

    // disable uart and clear pending interrupts
    put32(UART0_CR, 0);
    put32(UART0_ICR, 0x7FF);

    // calculate baud rate divisors from BAUD_RATE (48 mhz clock)
    // bauddiv = UART_CLOCK / (16 * baud), ibrd = integer part, fbrd = round(fraction * 64)
    unsigned int divisor = 16 * BAUD_RATE;
    unsigned int ibrd = UART_CLOCK / divisor;
    unsigned int fbrd = ((UART_CLOCK % divisor) * 64 + divisor / 2) / divisor;
    put32(UART0_IBRD, ibrd);
    put32(UART0_FBRD, fbrd);

    // set line control: enable fifo (bit 4) and 8bit data (bits 5-6)
    put32(UART0_LCRH, (1<<4) | (3<<5));

    // enable uart, tx, rx (bits 8, 9)
    put32(UART0_CR, (1<<0) | (1<<8) | (1<<9));
}

void uart_send (char c)
{
    while(get32(UART0_FR) & (1<<5)) {}
    put32(UART0_DR, c);
}

char uart_recv (void)
{
    while(get32(UART0_FR) & (1<<4)) {}
    return(get32(UART0_DR) & 0xFF);
}

void uart_send_string(char* str)
{
    for (int i = 0; str[i] != '\0'; i ++) {
        uart_send((char)str[i]);
    }
}