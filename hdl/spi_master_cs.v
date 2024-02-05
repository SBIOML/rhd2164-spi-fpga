///////////////////////////////////////////////////////////////////////////////
// Description: SPI (Serial Peripheral Interface) Master
//              With single chip-select (AKA Slave Select) capability
//
//              Supports arbitrary length byte transfers.
// 
//              Instantiates a SPI Master and adds single CS.
//              If multiple CS signals are needed, will need to use different
//              module, OR multiplex the CS from this at a higher level.
//
// Note:        i_clk must be at least 2x faster than i_SPI_Clk
//
// Parameters:  SPI_MODE, can be 0, 1, 2, or 3.  See above.
//              Can be configured in one of 4 modes:
//              Mode | Clock Polarity (CPOL/CKP) | Clock Phase (CPHA)
//               0   |             0             |        0
//               1   |             0             |        1
//               2   |             1             |        0
//               3   |             1             |        1
//
//              CLKS_PER_HALF_BIT - Sets frequency of o_sclk.  o_SPI_Clk is
//              derived from i_clk.  Set to integer number of clocks for each
//              half-bit of SPI data.  E.g. 100 MHz i_clk, CLKS_PER_HALF_BIT = 2
//              would create o_SPI_CLK of 25 MHz.  Must be >= 2
//
//              MAX_BYTES_PER_CS - Set to the maximum number of bytes that
//              will be sent during a single CS-low pulse.
// 
//              CS_INACTIVE_CLKS - Sets the amount of time in clock cycles to
//              hold the state of Chip-Selct high (inactive) before next 
//              command is allowed on the line.  Useful if chip requires some
//              time when CS is high between trasnfers.
///////////////////////////////////////////////////////////////////////////////

module spi_master_cs (
  // Control/Data Signals,
  input i_rst,     // FPGA Reset
  input i_clk,     // FPGA Clock

  // Control registers
  input [15:0] i_clk_div,
  input [7:0] i_clks_wait_after_done,

  // TX (MOSI) Signals
  input [15:0]  i_din,    // Byte to transmit on MOSI
  input         i_start,   // Data Valid Pulse with i_din
  output        o_done,    // Transmit Ready for next byte

  // RX (MISO) Signals
  output reg [15:0] o_dout_a,   // Byte received on MISO A
  output reg [15:0] o_dout_b,   // Byte received on MISO B

  // SPI Interface
  output o_sclk,
  input  i_miso,
  output o_mosi,
  output o_cs
);

  localparam IDLE        = 2'b00;
  localparam TRANSFER    = 2'b01;
  localparam CS_INACTIVE = 2'b10;

  wire [15:0] r_dout_a;
  wire [15:0] r_dout_b;

  reg [1:0] r_sm_cs;
  reg r_csn;
  reg [7:0] r_cs_inactive_cnt;
  wire w_master_ready;

  // Instantiate Master
  spi_master spi_master_inst (
    // Control/Data Signals,
    .i_rst(i_rst), // FPGA Reset
    .i_clk(i_clk), // FPGA Clock

    // Control registers
    .i_clks_wait_after_done(i_clks_wait_after_done),
    .i_clk_div(i_clk_div),

    // TX (MOSI) Signals
    .i_din(i_din),          // Byte to transmit
    .i_start(i_start),      // Data Valid Pulse 
    .o_done(w_master_ready),// Transmit Ready for Byte

    // RX (MISO) Signals
    .o_dout_a(r_dout_a), // Byte received on MISO
    .o_dout_b(r_dout_b),

    // SPI Interface
    .o_sclk(o_sclk),
    .i_miso(i_miso),
    .o_mosi(o_mosi)
  );

  // Purpose: Control CS line using State Machine
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      r_sm_cs <= IDLE;
      r_csn  <= 1'b1;   // Resets to high
      r_cs_inactive_cnt <= i_clks_wait_after_done;
      o_dout_a <= 16'b0;
      o_dout_b <= 16'b0;
    end else begin
      case (r_sm_cs)      
      IDLE: 
      begin
        if (r_csn & i_start) begin // Start of transmission
          r_csn  <= 1'b0;       // Drive CS low
          r_sm_cs <= TRANSFER;   // Transfer bytes
        end
      end 
      TRANSFER: 
      begin
        // Wait until SPI is done transferring do next thing
        if (w_master_ready) begin
            r_csn  <= 1'b1; // we done, so set CS high
            o_dout_a <= r_dout_a;
            o_dout_b <= {r_dout_b[15:1], i_miso};  // Sample MISOB on rising edge
            r_cs_inactive_cnt <= i_clks_wait_after_done;
            r_sm_cs <= CS_INACTIVE;
        end // if (w_master_ready)
      end // case: TRANSFER

      CS_INACTIVE:
      begin
        r_cs_inactive_cnt <= r_cs_inactive_cnt - 1'b1;
        if (r_cs_inactive_cnt == 0) begin
          r_sm_cs <= IDLE;
        end
      end

      default:
        begin
          r_csn  <= 1'b1; // we done, so set CS high
          r_sm_cs <= IDLE;
        end
      endcase // case (r_sm_cs)
    end
  end // always @ (posedge i_clk or negedge i_rst)

  assign o_cs = r_csn;
  assign o_done = (r_sm_cs == IDLE) & ~i_start;

endmodule // SPI_Master_With_Single_CS

