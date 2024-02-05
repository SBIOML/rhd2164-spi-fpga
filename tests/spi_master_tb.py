import cocotb
from cocotb.clock import Clock
import cocotb.triggers
from cocotb.triggers import Edge, RisingEdge, Timer, FallingEdge, ClockCycles
import random


async def init_dut(dut):
    dut.i_rst.value = 0
    dut.i_clk_div.value = 10
    dut.i_clks_wait_after_done.value = 4
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
        dut.i_miso.value = (data >> (15 - s)) & 1
        await FallingEdge(dut.o_sclk)  # data shifted falling edge
    await RisingEdge(dut.o_done)


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
async def clock_divider(dut):
    await init_dut(dut)

    for d in (1, 2, 4, 8, 16):
        dut.i_rst.value = 0
        await RisingEdge(dut.i_clk)
        dut.i_rst.value = 1
        await RisingEdge(dut.i_clk)

        dut.i_clk_div.value = d
        await start_transfer(dut, 0x0000)
        await Edge(dut.o_sclk)  # Wait for rising edge
        for _ in range(dut.i_clk_div.value + 1):
            await RisingEdge(dut.i_clk)
            # print(dut.o_sclk.value)
        assert dut.o_sclk.value == 0


@cocotb.test()
async def transfer_done(dut):
    await init_dut(dut)
    await start_transfer(dut, 0x0000)
    result = await cocotb.triggers.First(Timer(50, units="us"), RisingEdge(dut.o_done))
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
            sent |= dut.o_mosi.value << (15 - j)

        await RisingEdge(dut.o_done)
        dut._log.info(f"{i}: Expected {hex(val)}, MOSI sent {hex(sent)}")

        assert sent == val


@cocotb.test()
async def read_spi(dut):
    await init_dut(dut)
    for i in range(10):
        a = random.randint(0, 0xFFFF)
        b = random.randint(0, 0xFFFF)
        b16 = random.randint(0, 1)  # Dummy value

        await start_transfer(dut, 0x0000)
        dut.i_miso.value = b16
        for s in range(16):
            await RisingEdge(dut.i_clk)
            await RisingEdge(dut.o_sclk)
            dut.i_miso.value = (a >> (15 - s)) & 1
            await RisingEdge(dut.i_clk)
            await FallingEdge(dut.o_sclk)
            dut.i_miso.value = (b >> (15 - s)) & 1
        # Sample on CS rising edge
        await RisingEdge(dut.o_done)

        # Sample on CS rising edge
        rx_a = dut.o_dout_a.value
        rx_b = dut.o_dout_b.value

        dut._log.info(
            f"({i}) a: Expected {hex(a)}, rx'd {hex(rx_a)}. b: Expected {hex(b)}, rx'd {hex(rx_b)}"
        )
        assert rx_a == a and rx_b == b
