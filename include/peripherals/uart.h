#pragma once

#include "peripherals/base.h"

#define UART_CLOCK 48000000                 // pl011 reference clock (48 mhz)
#define BAUD_RATE 115200                    // change this to use another baud rate

#define UART0_BASE (PBASE + 0x201000)
#define UART0_DR (UART0_BASE + 0x00)
#define UART0_FR (UART0_BASE + 0x18)
#define UART0_IBRD (UART0_BASE + 0x24)
#define UART0_FBRD (UART0_BASE + 0x28)
#define UART0_LCRH (UART0_BASE + 0x2C)
#define UART0_CR (UART0_BASE + 0x30)
#define UART0_ICR (UART0_BASE + 0x44)
