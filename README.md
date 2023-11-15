# FPGA RHD2164 SPI

## Introduction

This repo is an implementation of a custom SPI driver that allows an FPGA to interact with RHD2164, including the DDR mode during sampling.

## System Overview

### SPI

The figure below shows the conceptual overview of the system. Since SPI is widely available as a normal peripheral, this implementation is not flexible enough to be used as a general-purpose SPI. With Xilinx FPGAs, an AXI interface should be used to expose the RHD SPI, located in the Programmable Logic (PL), to the Processing System (PS). Among others, this allows PYNQ to access it as a memory-mapped peripheral.

![System block](img/rhd-spi-system.png)

The SPI sampling subsystem **[TODO]** is a little bit trickier to implement, since Intan's RHD2164 CONVERT command has a very weird sampling pattern. Consequently, the SPI data reception is split into two branches, which are selectively chosen depending on the `i_din[15]` and `i_din[14]` bits. The figure below illustrates the block design.

![Sampling subsystem block](img/rhd-spi-sampling.png)

### AXI

In Xilinx PS-PL applications, AXI can be used to bridge the PS and the PL by memory-mapping HDL ports. As such, this design provides an AXI Block Design to easily access the SPI module within a PS environment.

## HDL development setup

Personally, I'd recommend developing the HDL code and testbench in a nice IDE like VS Code. Custom HDL sources are located in `source/`.

This project uses the [cocotb](https://docs.cocotb.org/en/stable/) Python library to write the testbench, which is located under `sim/`. Refer to cocotb's documentation to know how to set it up and use it.

## Xilinx development setup

### Vivado

The original Vivado version used is 2022.1, so the project may very well break if another version is used.

To get started quickly, open Vivado and create a new project with your target board. Then, add the sources located in `source/` to the project.

Generate the block design: `Tools -> Run tcl script -> <path-to-project>/vivado/axi-rhd-spi.tcl`. The block design should get generated. Make sure the _Zynq Processing System_ is configured correctly for your board.

You should now be ready to develop (you should still follow the [development setup](#hdl-development-setup)), simulate, generate the bitstream, etc.

### Vitis

Vitis is used to create the Processing System-side application, which may or may not communicate with the PL.

To use Vitis, just follow any well-made Vitis tutorial, such as [Digilent's](https://digilent.com/reference/programmable-logic/guides/getting-started-with-ipi).

Some more varied and advanced Vitis tutorials are available on Xilinx's [Vitis-Tutorials repo](https://github.com/Xilinx/Vitis-Tutorials).

A working barebones demo is located at `vitis/main.c`, which simply sends SPI packets. The payload starts at `0x0000` and increments by 1 after every packet.

## [TODO] PYNQ development setup

## References

- Verilog [tutorial](https://www.chipverify.com/tutorials/verilog)
- [Verilator](https://verilator.org/guide/latest/index.html), a Verilog/SystemVerilog compiler to C++/SystemC
- [cocotb](https://docs.cocotb.org/en/stable/index.html), a python library to build SystemVerilog and Verilog testbenches
- Nandland's SPI driver [source](https://github.com/nandland/spi-master)
