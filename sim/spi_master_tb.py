import cocotb
from cocotb.clock import Clock
import cocotb.triggers
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.types import LogicArray

import random

async def init_dut(dut):
    dut.i_rst.value = 0
    clock = Clock(dut.i_clk, 125, units="ns")  # Create a 1us period clock on port clk
    cocotb.start_soon(clock.start(start_high=False))
    
    for _ in range(2):
        await RisingEdge(dut.i_clk)

    dut.i_rst.value = 1

async def start_transfer(dut, data):
    dut.i_din.value = data
    dut.i_start.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_start.value = 0
    await RisingEdge(dut.i_clk)

async def sample_16(clk, signal):
    for i in range(16):
        await RisingEdge(clk)
        yield signal.value  # this means "send back to the for loop"

async def miso_sim(dut, data):
    for s in range(16):
        dut.i_miso.value = (data >> (15-s)) & 1
        await RisingEdge(dut.o_sclk)
        await FallingEdge(dut.o_sclk)

@cocotb.test()
async def start(dut):
    await init_dut(dut)

    for _ in range(2):
        await RisingEdge(dut.i_clk)

    assert dut.o_cs.value == 1

    dut.i_start.value = 1

    for _ in range(10):
        await RisingEdge(dut.i_clk)

    assert dut.o_cs.value == 0

@cocotb.test()
async def transfer_done(dut):
    await init_dut(dut)
    await start_transfer(dut, 0x0000)
    result = await cocotb.triggers.First(Timer(50, units='us'), RisingEdge(dut.o_done))
    assert type(result) != Timer

@cocotb.test()
async def transfer_rx_done(dut):
    await init_dut(dut)
    await start_transfer(dut, 0x0000)
    assert dut.o_rx_done.value == 0
    result = await cocotb.triggers.First(Timer(50, units='us'), RisingEdge(dut.o_rx_done))
    assert type(result) != Timer


@cocotb.test()
async def write_spi(dut):
    await init_dut(dut)
    for i in range(10):
        sent = 0
        val = random.randint(0, 0xFFFF)
        await start_transfer(dut, val)
        assert dut.i_start.value == 0
        for j in range(16):
            # Emulate sampling
            await RisingEdge(dut.o_sclk)
            sent |= dut.o_mosi.value << (15-j)

        await RisingEdge(dut.o_done)
        #for i in range(20):
        #    await RisingEdge(dut.o_done.value)
        #    print(f"DONE value: {dut.o_done.value}")
        print(f"{i}: Expected {hex(val)}, MOSI sent {hex(sent)}")
        assert sent == val

@cocotb.test()
async def read_spi_mode0(dut):
    await init_dut(dut)

    for i in range(10):
        val = random.randint(0, 0xFFFF)
        await start_transfer(dut, 0)
        await miso_sim(dut, val)
        #assert dut.o_done.value == 1
        #print(f"{i}: Expected {hex(val)}, o_dout {hex(dut.o_dout.value)}")
        assert dut.o_dout.value == val

@cocotb.test()
async def read_spi_ddr(dut):
    await init_dut(dut)
    dut._log.info(f"TODO SPI DDR")