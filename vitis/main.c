#include <stdio.h>
#include "platform.h"
#include "xgpio.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

int main()
{
    init_platform();

    XGpio din, io, dout;

    // AXI GPIO 0 : 1 port, 16-bits output, DATA IN
    XGpio_Initialize(&din, XPAR_AXI_GPIO_0_DEVICE_ID); // Initialize DR
    XGpio_SetDataDirection(&din, 1, 0x0); // out

    // AXI GPIO 1 : 2 port
    // Port 1: 1-bit output, START
    // Port 2: 1-bit input, DONE
    XGpio_Initialize(&io, XPAR_AXI_GPIO_1_DEVICE_ID); // Initialize DR
    XGpio_SetDataDirection(&io, 1, 0x1); // in
    XGpio_SetDataDirection(&io, 2, 0x0); // out

    // AXI GPIO 2 : 2 ports
    // Port 1: 16-bit input, DOUT_A
    // Port 2: 16-bit input, DOUT_B
    XGpio_Initialize(&dout, XPAR_AXI_GPIO_2_DEVICE_ID); // Initialize DR
    XGpio_SetDataDirection(&dout, 1, 0xFFFF); // in
    XGpio_SetDataDirection(&dout, 2, 0xFFFF); // in

    uint16_t val = 0x3000; // if 2 MSBs are 00, will use ddr
    uint16_t dout_a = 0;
    uint16_t dout_b = 0;
    while (1) {
    	// Write some data to dout
	XGpio_DiscreteWrite(&din, 1, ++val); // Write data for MOSI
    	XGpio_DiscreteWrite(&io, 1, 1); // Start transfer
    	XGpio_DiscreteWrite(&io, 1, 0);
    	usleep(200000);
    	dout_a = XGpio_DiscreteRead(&dout, 1);
    	dout_b = XGpio_DiscreteRead(&dout, 2);
    }
}

