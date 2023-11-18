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

module spi_master #(
  parameter CLKS_PER_HALF_BIT = 4,
  parameter CLKS_WAIT_AFTER_DONE = 4
) (
  // Control/Data Signals,
  input i_rst, // FPGA Reset
  input i_clk, // FPGA Clock

  // TX (MOSI) Signals
  input [15:0] i_din,    // Byte to transmit on MOSI
  input        i_start,  // Data Valid Pulse with i_din
  output reg   o_done,   // Transmit Ready for next byte

  // RX (MISO) Signals
  output reg [15:0] o_dout_a, // Byte received on MISOA
  output reg [15:0] o_dout_b, // Byte received on MISOB

  // SPI Interface
  output reg o_sclk,
  input      i_miso,
  output reg o_mosi
);

  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_sclk_cnt;
  reg [$clog2(CLKS_WAIT_AFTER_DONE)-1:0] r_wait_cnt;
  
  reg r_done; // Transfer done, waiting for CLKS_WAIT_AFTER_DONE
  reg r_sclk;
  reg [5:0] r_sclk_edges; // 32 clock edges / transfer
  reg r_sclk_rising;
  reg r_sclk_falling;
  reg        r_start;
  reg [15:0] r_tx;

  reg [3:0] r_tx_cnt;

  reg [15:0] r_rx_a; // DDR sampler ch A
  reg [15:0] r_rx_b; // DDR sampler ch B
  reg [3:0] r_ddr_rx_cnt_a; // 16d counter
  reg [4:0] r_ddr_rx_cnt_b; // Need to sample it 1 extra time


  // SCLK Generator
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      o_done <= 1'b0;
      r_done <= 1'b0;
      r_sclk_edges <= 0;
      r_sclk_rising  <= 1'b0;
      r_sclk_falling <= 1'b0;
      r_sclk <= 1'b0; // default state to sclk
      r_sclk_cnt <= 0;
      r_wait_cnt <= CLKS_WAIT_AFTER_DONE-1;
    end else begin
      r_sclk_rising  <= 1'b0;
      r_sclk_falling <= 1'b0;
      
      if (i_start) begin
        r_done <= 1'b0;
        o_done <= 1'b0;
        r_sclk_edges <= 6'd32;  // # edges in one byte = 16, but we send 2 kek
        r_wait_cnt <= CLKS_WAIT_AFTER_DONE-1;
      end else if (r_sclk_edges > 0) begin
        o_done <= 1'b0;
        r_done <= 1'b0;
        if (r_sclk_cnt == CLKS_PER_HALF_BIT*2-1) begin
          // time = full-bit, falling edge sclk + shift
          r_sclk_edges <= r_sclk_edges - 1'b1;
          r_sclk_falling <= 1'b1;
          r_sclk_cnt <= 0;
          r_sclk <= 1'b0;
        end else if (r_sclk_cnt == CLKS_PER_HALF_BIT-1) begin
          // time = half-bit, rising edge sclk + sampling
          r_sclk_edges <= r_sclk_edges - 1'b1;
          r_sclk_rising  <= 1'b1;
          r_sclk_cnt <= r_sclk_cnt + 1'b1;
          r_sclk <= 1'b1;
        end else begin
          r_sclk_cnt <= r_sclk_cnt + 1'b1;
        end
      end else begin
        r_done <= 1'b1;
        if (r_wait_cnt == 0) begin
            o_done <= 1'b1;
        end  else begin
            r_wait_cnt <= r_wait_cnt-1;
        end
      end 
    end // else: !if(~i_rst)
  end // always @ (posedge i_clk or negedge i_rst)


  // Purpose: Register i_din when Data Valid is pulsed and set dout MUX
  // Keeps local storage of byte in case higher level module changes the data
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      r_tx <= 16'd0;
      r_start <= 1'b0;
    end else begin
      r_start <= i_start; // 1 clock cycle delay
      if (i_start) begin
        r_tx <= i_din;
      end
    end // else: !if(~i_rst)
  end // always @ (posedge i_clk or negedge i_rst)


  // Purpose: Generate MOSI data
  // Works with both CPHA=0 and CPHA=1
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      o_mosi <= 1'b0;
      r_tx_cnt <= 4'd15;
    end else begin
      if (r_done) begin
        r_tx_cnt <= 4'd15;
      end else if (r_start) begin 
        // CPHA = 0 first bit (shift before first sclk edge)
        o_mosi <= r_tx[4'd15];
        r_tx_cnt <= 4'd14;
      end else if (r_sclk_falling) begin
        o_mosi <= r_tx[r_tx_cnt];
        r_tx_cnt <= r_tx_cnt - 1'b1;
      end
    end
  end
  
  // Read MISO in DDR mode
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      r_rx_a <= 0;
      r_rx_b <= 0;
      r_ddr_rx_cnt_a <= 4'd15;
      r_ddr_rx_cnt_b <= 5'd16;
      o_dout_a <= 0;
      o_dout_b <= 0;
    end else begin
      // Default Assignments
      if (r_done) begin
        r_ddr_rx_cnt_a <= 4'd15;
        r_ddr_rx_cnt_b <= 5'd16;
        o_dout_a <= r_rx_a;
        o_dout_b <= r_rx_b;
      end else begin
        if (r_sclk_rising) begin
          // rising edge == miso B
          r_ddr_rx_cnt_b <= r_ddr_rx_cnt_b - 1'b1;
          // Skip first sclk edge
          if (r_ddr_rx_cnt_b < 5'd16) begin 
            r_rx_b[r_ddr_rx_cnt_b] <= i_miso;  // Sample data
          end
        end else if (r_sclk_falling) begin
          // falling edge == miso A
          r_rx_a[r_ddr_rx_cnt_a] <= i_miso;  // Sample data
          r_ddr_rx_cnt_a <= r_ddr_rx_cnt_a - 1'b1;
        end
      end
    end
  end

  // Purpose: Add clock delay to signals for alignment.
  always @(posedge i_clk or negedge i_rst) begin
    if (~i_rst) begin
      o_sclk  <= 0;
    end else begin
      o_sclk <= r_sclk;
    end // else: !if(~i_rst)
  end // always @ (posedge i_clk or negedge i_rst)
 

endmodule // SPI_Master
