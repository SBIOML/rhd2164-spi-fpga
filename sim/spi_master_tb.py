import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.types import LogicArray


async def SendBytes(dut, data):
    await RisingEdge(dut.i_clk)
    dut.i_din.value = data
    dut.i_start.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_start.value = 0
    await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_spi_master(dut):
    # I mean of course it's gonna work I took it online
    # Set initial input value to prevent it from floating
    dut.i_rst.value = 0
    print(f"DUT: {dut}")
    clock = Clock(dut.i_clk, 125, units="ns")  # Create a 1us period clock on port clk
    cocotb.start_soon(clock.start(start_high=False))
    await RisingEdge(dut.i_clk)
    dut.i_rst.value = 1

    misoval = ord("I")  # simulate intan
    await SendBytes(dut, 0xDEAD)

    for i in range(16):
        dut.i_miso.value = misoval >> (15 - i) & 0x1
        await RisingEdge(dut.o_sclk)
        print(f"SPI Rising Edge #{i}")
        print(f"RX DV: {dut.o_rx_done.value}, mosi: {dut.o_mosi.value}")

    print(hex(dut.o_dout.value))
