
#include <stdio.h>
#include "platform.h"
#include "xgpio.h"
#include "xparameters.h"
#include "xuartps.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

int main()
{
    init_platform();

    // INIT UART
    // https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842077/UART+standalone+driver
    XUartPs Uart_PS;
    XUartPs_Config *Config;
	Config = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
	XUartPs_CfgInitialize(&Uart_PS, Config, Config->BaseAddress);

	// INIT AXI GPIO

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

    uint16_t dout_a = 0;
    uint16_t dout_b = 0;
    uint8_t done = 0;
    char userInput[30] = {'0'};
	uint8_t cmd = 0;
	uint8_t reg = 0;
	uint8_t wdat = 0;
    while (1) {
    	/*
    	 You can open a serial port and write, for example :
    		- "r 12" to read register 12.
    		- "w 07 18" to write 18 into register 7.
	*/
    	if (XUartPs_IsReceiveData(XPAR_PS7_UART_1_BASEADDR)) {
    		int received = 0;
    		char rx = '0';
    		xil_printf("Received ");
    		while (rx != '\n') {
    			rx = XUartPs_RecvByte(XPAR_PS7_UART_1_BASEADDR);
    			userInput[received++] = rx;
        		xil_printf("%c", rx);
    		}
    		xil_printf(" tot = %d chars\n", received);

			switch (userInput[0]) {
			case 'r':
				cmd = 0b11;
				break;
			case 'w':
				// Get payload
				wdat = (userInput [5]-'0')*10 + userInput[6]-'0';
				cmd = 0b10;
				break;
			case 'c':
				cmd = 0b00;
				break;
			default:
				cmd = 0b00;
				break;
			}
			reg = (userInput [2]-'0')*10 + userInput[3]-'0';
    	}

    	// Write some data to dout
		uint16_t val = (((cmd<<6 | reg) & 0xFF )<< 8) | (wdat & 0xFF); // if 2 MSBs are 00, will use ddr
		XGpio_DiscreteWrite(&din, 1, val); // Write data for MOSI
    	XGpio_DiscreteWrite(&io, 1, 1); // Start transfer
    	done = XGpio_DiscreteRead(&io, 2);
    	XGpio_DiscreteWrite(&io, 1, 0);
    	usleep(1000000); // ms
    	done = XGpio_DiscreteRead(&io, 2);
    	dout_a = XGpio_DiscreteRead(&dout, 1);
    	dout_b = XGpio_DiscreteRead(&dout, 2);

    	xil_printf("%c at reg %c%c, mosi 0x%x, dout_a = 0x%x, dout_b = 0x%x\n", userInput[0], userInput[2], userInput[3], val, dout_a, dout_b);
    }
}



