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

module spi_master_cs #(
  parameter SPI_MODE = 0,
  parameter CLKS_PER_HALF_BIT = 4,
  parameter CS_INACTIVE_CLKS = 4
) (
  // Control/Data Signals,
  input        i_rst,     // FPGA Reset
  input        i_clk,     // FPGA Clock

  // TX (MOSI) Signals
  input [15:0]  i_din,    // Byte to transmit on MOSI
  input         i_start,   // Data Valid Pulse with i_din
  output        o_done,    // Transmit Ready for next byte

  // RX (MISO) Signals
  output        o_rx_done, // Data Valid pulse (1 clock cycle)
  output [15:0] o_dout,   // Byte received on MISO A

  // SPI Interface
  output o_sclk,
  input  i_miso,
  output o_mosi,
  output o_cs
);

  localparam IDLE        = 2'b00;
  localparam TRANSFER    = 2'b01;
  localparam CS_INACTIVE = 2'b10;

  reg [1:0] r_SM_CS;
  reg r_CS_n;
  reg [$clog2(CS_INACTIVE_CLKS):0] r_CS_Inactive_Count;
  wire w_Master_Ready;

  // Instantiate Master
  spi_master #(
    .SPI_MODE(SPI_MODE),
    .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
  ) spi_master_inst (
    // Control/Data Signals,
    .i_rst(i_rst), // FPGA Reset
    .i_clk(i_clk),   // FPGA Clock

    // TX (MOSI) Signals
    .i_din(i_din),          // Byte to transmit
    .i_start(i_start),      // Data Valid Pulse 
    .o_done(w_Master_Ready),// Transmit Ready for Byte

    // RX (MISO) Signals
    .o_rx_done(o_rx_done),  // Data Valid pulse (1 clock cycle)
    .o_dout(o_dout),        // Byte received on MISO

    // SPI Interface
    .o_sclk(o_sclk),
    .i_miso(i_miso),
    .o_mosi(o_mosi)
  );

  // Purpose: Control CS line using State Machine
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      r_SM_CS <= IDLE;
      r_CS_n  <= 1'b1;   // Resets to high
      r_CS_Inactive_Count <= CS_INACTIVE_CLKS;
    end else begin
      case (r_SM_CS)      
      IDLE: 
      begin
        if (r_CS_n & i_start) begin // Start of transmission
          r_CS_n  <= 1'b0;       // Drive CS low
          r_SM_CS <= TRANSFER;   // Transfer bytes
        end
      end 
      TRANSFER: 
      begin
        // Wait until SPI is done transferring do next thing
        if (w_Master_Ready) begin
            r_CS_n  <= 1'b1; // we done, so set CS high
            r_CS_Inactive_Count <= CS_INACTIVE_CLKS;
            r_SM_CS             <= CS_INACTIVE;
        end // if (w_Master_Ready)
      end // case: TRANSFER

      CS_INACTIVE:
      begin
        if (r_CS_Inactive_Count > 0) begin
          r_CS_Inactive_Count <= r_CS_Inactive_Count - 1'b1;
        end else begin
          r_SM_CS <= IDLE;
        end
      end

      default:
        begin
          r_CS_n  <= 1'b1; // we done, so set CS high
          r_SM_CS <= IDLE;
        end
      endcase // case (r_SM_CS)
    end
  end // always @ (posedge i_clk or negedge i_rst)

  assign o_cs = r_CS_n;

  //assign o_done  = ((r_SM_CS == IDLE) | (r_SM_CS == TRANSFER && w_Master_Ready == 1'b1)) & ~i_start;
  assign o_done  = (r_SM_CS == IDLE) & ~i_start;

endmodule // SPI_Master_With_Single_CS

