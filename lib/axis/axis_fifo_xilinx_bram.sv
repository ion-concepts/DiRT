//-------------------------------------------------------------------------------
// File:    axis_fifo_xilinx_bram.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Width of datapath.
// * Size (Depth) of FIFO
// * Usage of output register.
//
// Description:
//
//  License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

`default_nettype none

module axis_fifo_xilinx_bram
  #(
    parameter WIDTH=32,
    parameter SIZE=9,
    parameter ULTRA=0,
    parameter OUTPUT_REGISTER=1
    )
   (
    input wire               clk,
    input wire               rst,
    // Input Bus
    input wire [WIDTH-1:0]   in_tdata,
    input wire               in_tvalid,
    output logic             in_tready,
    // Output bus
    output logic [WIDTH-1:0] out_tdata,
    output logic             out_tvalid,
    input wire               out_tready,
    // Debug
    output logic [SIZE:0]    space,
    output logic [SIZE:0]    occupied
    );

   logic 			     write;
   logic 			     read;

   logic                             read_valid;
   logic                             read_enable;
   localparam                        BRAM_LATENCY = OUTPUT_REGISTER ? 2 : 1;
   logic [BRAM_LATENCY-1:0]          read_valid_q;

   always_ff @(posedge clk) begin
      if (rst) begin
         read_valid_q <= 2'b0;
      end else if (read_enable) begin
         read_valid_q <= {read_valid_q[BRAM_LATENCY-2:0], read_valid};
      end
   end

   logic [SIZE-1:0] wr_addr;
   logic [SIZE-1:0] rd_addr;

   logic            full;

   always_comb begin
      in_tready  = ~full;
      out_tvalid = read_valid_q[BRAM_LATENCY-1];
      write 	 = in_tvalid & in_tready;
      read 	 = out_tvalid & out_tready;
   end

   always_comb begin
      read_valid = rd_addr != wr_addr;
      read_enable = out_tready || ~out_tvalid;
   end

   always_ff @(posedge clk) begin
      if (rst) begin
         rd_addr <= 0;
      end else if (read_enable && read_valid) begin
         rd_addr <= rd_addr + 1;
      end
   end

   always_ff @(posedge clk) begin
      if (rst) begin
         wr_addr <= 0;
      end else if (write) begin
         wr_addr <= wr_addr + 1;
      end
   end

   // Use infered RAM rather than tech specific library cell for now.
   ram_dual_port_2clk
     #(.WIDTH(WIDTH),.SIZE(SIZE),
       .ULTRA(ULTRA),.OUTPUT_REGISTER(OUTPUT_REGISTER))
   ram
     (
      .clk1(clk),
      .enable1(1'b1),
      .write1(write),
      .addr1(wr_addr),
      .data_in1(in_tdata),
      .data_out1(),

      .clk2(clk),
      .enable2(read_enable),
      .write2(1'b0),
      .addr2(rd_addr),
      .data_in2({WIDTH{1'b1}}),
      .data_out2(out_tdata)
      );

   logic [SIZE-1:0] dont_write_past_me;
   logic 	    becoming_full;

   always_comb begin
      dont_write_past_me = rd_addr - 2;
      becoming_full = wr_addr == dont_write_past_me;
   end

   always_ff @(posedge clk)
     if(rst)
       full <= 0;
     else if(read & ~write)
       full <= 0;
     else if(write & ~read & becoming_full)
       full <= 1;

   localparam NUMLINES = (1<<SIZE);
   always_ff @(posedge clk)
     if(rst)
       space <= NUMLINES;
     else if(read & ~write)
       space <= space + 1'b1;
     else if(write & ~read)
       space <= space - 1'b1;

   always_ff @(posedge clk)
     if(rst)
       occupied <= 16'b0;
     else if(read & ~write)
       occupied <= occupied - 1'b1;
     else if(write & ~read)
       occupied <= occupied + 1'b1;


endmodule // axis_fifo_xilinx_bram

`default_nettype wire
