module rhd_wrapper (
    // Control/Data Signals,
    input i_rst,     // FPGA Reset
    input i_clk,     // FPGA Clock

    // Control registers
    input [23:0] i_ctrl, // [0:15] = i_clk_div, [16:23] = i_clk_delay

    // Status
    input         i_start,   // Data Valid Pulse with i_din
    output        o_done,    // Transmit Ready for next byte

    // TX (MOSI) Signals
    input [15:0]  i_din,    // Byte to transmit on MOSI
    

    // RX (MISO) Signals
    output [31:0] o_dout,

    // SPI Interface
    output o_sclk,
    input  i_miso,
    output o_mosi,
    output o_cs
);

    wire [15:0] w_clk_div;
    wire [7:0] w_clks_wait_after_done;
    wire [15:0] w_dout_a;
    wire [15:0] w_dout_b;

    assign w_clks_wait_after_done = i_ctrl[23:16];
    assign w_clk_div = i_ctrl[15:0];

    assign o_dout = {w_dout_b, w_dout_a};

    spi_master_cs spi_master_cs_inst (
        // Control/Data Signals,
        .i_rst(i_rst), // FPGA Reset
        .i_clk(i_clk), // FPGA Clock

        // Control registers
        .i_clks_wait_after_done(w_clks_wait_after_done),
        .i_clk_div(w_clk_div),

        // TX (MOSI) Signals
        .i_din(i_din),          // Byte to transmit
        .i_start(i_start),      // Data Valid Pulse 
        .o_done(o_done),// Transmit Ready for Byte

        // RX (MISO) Signals
        .o_dout_a(w_dout_a), // Byte received on MISO
        .o_dout_b(w_dout_b),

        // SPI Interface
        .o_sclk(o_sclk),
        .i_miso(i_miso),
        .o_mosi(o_mosi),
        .o_cs(o_cs)
    );

endmodule