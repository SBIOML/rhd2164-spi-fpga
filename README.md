# RHD2164 SPI FPGA IP

## Introduction

This repo is an implementation of a custom SPI driver that allows an FPGA to interact with RHD2164, including the DDR mode during sampling.

## AXI implementation

**TODO**

In Xilinx PS-PL applications, AXI must be used to bridge the PS and the PL by memory-mapping HDL ports. As such, this design (*will eventually*) provides an AXI Block Design to easily access the SPI module within a PS environment.

## How to get set up

VS Code works well for editing verilog code with one of the verilog extensions.

## References

- Verilog [tutorial](https://www.chipverify.com/tutorials/verilog)
- [Verilator](https://verilator.org/guide/latest/index.html), a Verilog/SystemVerilog compiler to C++/SystemC
- [Cocotb](https://docs.cocotb.org/en/stable/index.html), a python library to build SystemVerilog and Verilog testbenches
- Nandland's SPI driver [source](https://github.com/nandland/spi-master)
