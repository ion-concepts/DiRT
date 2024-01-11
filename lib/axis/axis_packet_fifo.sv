//-------------------------------------------------------------------------------
// File:    axis_packet_fifo.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
//
// Wraps regular stream FIFO's (1 clock only) to make them packet aware.
// Only allows a packet to egress once its fully ingressed. This is very useful
// when packet beats arrive at a slow rate relative to the (current) clock.
//
//  Parameterizable:
//  * Width of datapath.
//  * Size (Depth) of FIFO
//  * FPGA vendor
//  * Technology Library Vendor (Xilinx/Altera/etc)
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_packet_fifo
  #(
    parameter WIDTH=64,  // AXIS datapath width.
    parameter SIZE=9,    // Size of FIFO (LOG2)
    parameter MAX_PACKETS=8, // Sets number of packets that can be in FIFO concurrently (LOG2)
    parameter VENDOR="xilinx",
    parameter ULTRA=0
    )


     (
      input logic                  clk,
      input logic                  rst,
      input logic                  sw_rst,
      //
      // Input Bus
      //
      input logic [WIDTH-1:0]      in_tdata,
      input logic                  in_tvalid,
      output logic                 in_tready,
      input logic                  in_tlast,
      //
      // Output Bus
      //
      output logic [WIDTH-1:0]     out_tdata,
      output logic                 out_tvalid,
      input logic                  out_tready,
      output logic                 out_tlast,
      // Occupancy
      output logic [SIZE:0]        space,
      output logic [SIZE:0]        occupied,
      output reg [MAX_PACKETS-1:0] packet_count
     
      );

   
   logic                           packet_in, packet_out;
   logic                           in_tmp_tvalid;
   logic                           in_tmp_tready;
   logic                           out_tmp_tvalid;
   logic                           out_tmp_tready;
   

   always_ff @(posedge clk)
     if (rst) 
       packet_count <= 0;
     else if (sw_rst)
        packet_count <= 0;
      // packet in and packet out in same cycle equals no net change in packet count.
      else if (packet_in && ~packet_out)
        packet_count <= packet_count + 1;
      else if (packet_out && ~packet_in)
        packet_count <= packet_count - 1;
   
   always_comb begin
      // Stops packet count wrapping by back pressuring.
      // TODO: We could change this to drop rather than back pressure.
      in_tmp_tvalid = !(&packet_count) ? in_tvalid : 1'b0;
      in_tready = !(&packet_count) ? in_tmp_tready : 1'b0;

      // If there are any whole packets buffered then advertize
      // available data on egress.
      out_tvalid = |packet_count ? out_tmp_tvalid : 1'b0;
      out_tmp_tready = |packet_count ? out_tready : 1'b0;

      // Whole packets are counted when TLAST passes this point.
      packet_out = out_tmp_tvalid && out_tmp_tready && out_tlast;
      packet_in = in_tmp_tvalid && in_tmp_tready && in_tlast;
   end
   
   axis_fifo
     #(
       .WIDTH(WIDTH+1),
       .SIZE(SIZE),
       .VENDOR(VENDOR),
       .ULTRA(ULTRA)
       )
   axis_fifo_i0
     (
      .clk(clk), 
      .rst(rst),
      // Input
      .in_tdata({in_tlast,in_tdata}), 
      .in_tvalid(in_tmp_tvalid), 
      .in_tready(in_tmp_tready), 
      // Output
      .out_tdata({out_tlast,out_tdata}), 
      .out_tvalid(out_tmp_tvalid), 
      .out_tready(out_tmp_tready),
      // Status
      .space(space), 
      .occupied(occupied)
      );

endmodule // axis_packet_fifo
