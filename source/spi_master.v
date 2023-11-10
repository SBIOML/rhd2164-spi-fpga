///////////////////////////////////////////////////////////////////////////////
// Description: SPI (Serial Peripheral Interface) Master
//              Creates master based on input configuration.
//              Sends a byte one bit at a time on MOSI
//              Will also receive byte data one bit at a time on MISO.
//              Any data on input byte will be shipped out on MOSI.
//
//              To kick-off transaction, user must pulse i_start.
//              This module supports multi-byte transmissions by pulsing
//              i_start and loading up i_din when o_done is high.
//
//              This module is only responsible for controlling Clk, MOSI, 
//              and MISO.  If the SPI peripheral requires a chip-select, 
//              this must be done at a higher level.
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
//              More: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface_Bus#Mode_numbers
//              CLKS_PER_HALF_BIT - Sets frequency of o_sclk.  o_SPI_Clk is
//              derived from i_clk.  Set to integer number of clocks for each
//              half-bit of SPI data.  E.g. 100 MHz i_clk, CLKS_PER_HALF_BIT = 2
//              would create o_SPI_CLK of 25 MHz.  Must be >= 2
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1us/1ns

module spi_master
  #(parameter SPI_MODE = 0,
    parameter CLKS_PER_HALF_BIT = 4) // SPI_CLK = MAIN_CLK/(CLK_PER_HALF_BIT*2)
  (
   // Control/Data Signals,
    input        i_rst,     // FPGA Reset
    input        i_clk,       // FPGA Clock

    // TX (MOSI) Signals
    input [15:0]  i_din,        // Byte to transmit on MOSI
    input        i_start,          // Data Valid Pulse with i_din
    output reg   o_done,       // Transmit Ready for next byte

    // RX (MISO) Signals
    output reg       o_rx_done,     // Data Valid pulse (1 clock cycle)
    output reg [15:0] o_dout,   // Byte received on MISO

    // SPI Interface
    output reg o_sclk,
    input      i_miso,
    output reg o_mosi
   );

  // SPI Interface (All Runs at SPI Clock Domain)
  wire w_CPOL;     // Clock polarity
  wire w_CPHA;     // Clock phase

  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_SPI_Clk_Count;
  reg r_SPI_Clk;
  reg [5:0] r_SPI_Clk_Edges;
  reg r_Leading_Edge;
  reg r_Trailing_Edge;
  reg       r_TX_DV;
  reg [15:0] r_TX_Byte;

  reg [3:0] r_RX_Bit_Count;
  reg [3:0] r_TX_Bit_Count;

  // CPOL: Clock Polarity
  // CPOL=0 means clock idles at 0, leading edge is rising edge.
  // CPOL=1 means clock idles at 1, leading edge is falling edge.
  assign w_CPOL  = (SPI_MODE == 2) | (SPI_MODE == 3);

  // CPHA: Clock Phase
  // CPHA=0 means the "out" side changes the data on trailing edge of clock
  //              the "in" side captures data on leading edge of clock
  // CPHA=1 means the "out" side changes the data on leading edge of clock
  //              the "in" side captures data on the trailing edge of clock
  assign w_CPHA  = (SPI_MODE == 1) | (SPI_MODE == 3);



  // Purpose: Generate SPI Clock correct number of times when DV pulse comes
  always @(posedge i_clk or negedge i_rst)
  begin
    if (~i_rst)
    begin
      o_done      <= 1'b0;
      r_SPI_Clk_Edges <= 0;
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;
      r_SPI_Clk       <= w_CPOL; // assign default state to idle state
      r_SPI_Clk_Count <= 0;
    end
    else
    begin

      // Default assignments
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;
      
      if (i_start)
      begin
        o_done      <= 1'b0;
        r_SPI_Clk_Edges <= 32;  // Total # edges in one byte ALWAYS 16, but we send 2 kek
      end
      else if (r_SPI_Clk_Edges > 0)
      begin
        o_done <= 1'b0;
        
        if (r_SPI_Clk_Count == CLKS_PER_HALF_BIT*2-1) // flip spi clk
        begin
          r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 1'b1;
          r_Trailing_Edge <= 1'b1;
          r_SPI_Clk_Count <= 0;
          r_SPI_Clk       <= ~r_SPI_Clk;
        end
        else if (r_SPI_Clk_Count == CLKS_PER_HALF_BIT-1)
        begin
          r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 1'b1;
          r_Leading_Edge  <= 1'b1;
          r_SPI_Clk_Count <= r_SPI_Clk_Count + 1'b1;
          r_SPI_Clk       <= ~r_SPI_Clk;
        end
        else
        begin
          r_SPI_Clk_Count <= r_SPI_Clk_Count + 1'b1;
        end
      end  
      else
      begin
        o_done <= 1'b1;
      end
      
      
    end // else: !if(~i_rst)
  end // always @ (posedge i_clk or negedge i_rst)


  // Purpose: Register i_din when Data Valid is pulsed.
  // Keeps local storage of byte in case higher level module changes the data
  always @(posedge i_clk or negedge i_rst)
  begin
    if (~i_rst)
    begin
      r_TX_Byte <= 16'h00;
      r_TX_DV   <= 1'b0;
    end
    else
      begin
        r_TX_DV <= i_start; // 1 clock cycle delay
        if (i_start)
        begin
          r_TX_Byte <= i_din;
        end
      end // else: !if(~i_rst)
  end // always @ (posedge i_clk or negedge i_rst)


  // Purpose: Generate MOSI data
  // Works with both CPHA=0 and CPHA=1
  always @(posedge i_clk or negedge i_rst)
  begin
    if (~i_rst)
    begin
      o_mosi     <= 1'b0;
      r_TX_Bit_Count <= 4'b1111; // send MSb first
    end
    else
    begin
      // If ready is high, reset bit counts to default
      if (o_done)
      begin
        r_TX_Bit_Count <= 4'b1111;
      end
      // Catch the case where we start transaction and CPHA = 0
      else if (r_TX_DV & ~w_CPHA)
      begin
        o_mosi     <= r_TX_Byte[4'b111];
        r_TX_Bit_Count <= 4'b1110;
      end
      else if ((r_Leading_Edge & w_CPHA) | (r_Trailing_Edge & ~w_CPHA))
      begin
        r_TX_Bit_Count <= r_TX_Bit_Count - 1'b1;
        o_mosi     <= r_TX_Byte[r_TX_Bit_Count];
      end
    end
  end


  // Purpose: Read in MISO data.
  always @(posedge i_clk or negedge i_rst)
  begin
    if (~i_rst)
    begin
      o_dout      <= 16'h0000;
      o_rx_done        <= 1'b0;
      r_RX_Bit_Count <= 4'b111;
    end
    else
    begin

      // Default Assignments
      o_rx_done   <= 1'b0;

      if (o_done) // Check if ready is high, if so reset bit count to default
      begin
        r_RX_Bit_Count <= 4'b1111;
      end
      else if ((r_Leading_Edge & ~w_CPHA) | (r_Trailing_Edge & w_CPHA))
      begin
        o_dout[r_RX_Bit_Count] <= i_miso;  // Sample data
        r_RX_Bit_Count            <= r_RX_Bit_Count - 1'b1;
        if (r_RX_Bit_Count == 4'b000)
        begin
          o_rx_done   <= 1'b1;   // Byte done, pulse Data Valid
        end
      end
    end
  end
  
  
  // Purpose: Add clock delay to signals for alignment.
  always @(posedge i_clk or negedge i_rst)
  begin
    if (~i_rst)
    begin
      o_sclk  <= w_CPOL;
    end
    else
      begin
        o_sclk <= r_SPI_Clk;
      end // else: !if(~i_rst)
  end // always @ (posedge i_clk or negedge i_rst)
  

endmodule // SPI_Master
