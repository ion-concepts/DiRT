//-------------------------------------------------------------------------------
// File:    axis_ipv4_packet_fifo.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
//
// Wraps regular stream FIFO's (1 clock only) to make them specificly IPv4 packet aware.
// Inspects IPv4 Headers of packet to find size and verifies there is local space to buffer 
// the entire packet...if there is not enough space packet is immediately dropped.
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

module axis_ipv4_packet_fifo
  #(
    parameter WIDTH=64,  // AXIS datapath width.
    parameter SIZE=9,    // Size of FIFO (LOG2)
    parameter MAX_PACKETS=8, // Sets number of packets that can be in FIFO concurrently (LOG2)
    parameter VENDOR="xilinx"
    )


   (
    input logic clk,
    input logic rst,
    //
    // CSR interface
    //
    input logic csr_reset_stats,
    output logic [31:0] csr_buffered_packets,
    output logic [31:0] csr_dropped_packets,
    //
    // Input Bus
    //
    axis_t.slave in_axis,
    //
    // Output Bus
    //
    axis_t.master out_axis
   
   
    );
   
   axis_t #(.WIDTH(WIDTH)) in_fifo_axis(.clk(clk));
   axis_t #(.WIDTH(WIDTH)) out_fifo_axis(.clk(clk));
   
   // Occupancy
   logic [SIZE:0] space;  
   logic [SIZE:0] occupied;
   logic [MAX_PACKETS-1:0] packet_count;
   logic                   enable_ready;
   
   
   //---------------------------------------------------------
   // State machine declarations
   //---------------------------------------------------------
   enum                    {
                            IDLE,
                            BUFFER,
                            DROP
                            } state;
   

   //-------------------------------------------------------------------------------
   // In DiRT, and IPv4 packet has the following alignment on 64b AXIS:
   // Beat1: [64:32] (last octets of possible Eth header), [31:16] VERS+IHL+DSCP, [15:0] Length
   // Beat2: [64:32] Src IP Addr, [31:0] Dst IP addr
   //
   //-------------------------------------------------------------------------------
     always_ff @(posedge clk)
       if(rst) begin
          state <= IDLE;
          enable_ready <= 1'b0;
       end else begin
          case(state)
            // Sit in IDLE state waiting for asserted TVALID that indicates first beat of an IPv$ packet.
            IDLE: begin 
               if (in_fifo_axis.tvalid) begin
                  // Is IPv4 packet size (in quad words) is smaller than remaining space in FIFO?
                  // (Also recall that by ignoring 3 LSB's of IPv4 size there mayne upto 7 more octets,
                  // hence not using >= )
                  if (in_fifo_axis.tdata[15:3] < space) begin
                     // Buffer packet
                     enable_ready <= 1'b1;
                     state <= BUFFER;
                  end else begin
                     enable_ready <= 1'b1;
                     state <= DROP;
                  end
               end // if (in_fifo_axis.tvalid)
            end
            // Sit in BUFFER adding burst beats to FIFO until TLAST is asserted
            BUFFER: begin
               if (in_fifo_axis.tvalid && in_fifo_axis.tready && in_fifo_axis.tlast) begin
                  state <= IDLE;
                  csr_buffered_packets <= csr_buffered_packets + 1'b1;
                  enable_ready <= 1'b0;
               end
            end
            // Sit in DROP discarding beats until TLAST is asserted
            DROP: begin
               if (in_fifo_axis.tvalid && in_fifo_axis.tready && in_fifo_axis.tlast) begin
                  state <= IDLE;
                  csr_dropped_packets <= csr_dropped_packets + 1'b1;
                  enable_ready <= 1'b0;
               end
            end
          endcase
       end


   //
   // 4 way combinatorial mux of the different valid/ready pairs from outputs.
   //
   always_comb begin
      out_fifo_axis.tvalid = (state == BUFFER) && enable_ready && in_fifo_axis.tvalid;
      in_fifo_axis.tready =
                          ((state == BUFFER) && enable_ready && out_fifo_axis.tready) | // Buffer this packet
                          ((state == DROP) && enable_ready); // Discard this packet
   end
  
   //-------------------------------------------------------------------------------
   // AXI minimal FIFO breaks all combinatorial through paths
   //-------------------------------------------------------------------------------
   axis_minimal_fifo_wrapper input_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis),
      .out_axis(in_fifo_axis),
      .space_out(),
      .occupied_out()
      );

   //-------------------------------------------------------------------------------
   // FIFO holds (potentially many) IPv4 packets
   //-------------------------------------------------------------------------------
   axis_packet_fifo_wrapper
     #(
       .SIZE(SIZE),
       .MAX_PACKETS(MAX_PACKETS)
       )
   axis_packet_fifo_wrapper_i0
     (
      .clk(clk),
      .rst(rst),
      .sw_rst(1'b0),
      .in_axis(out_fifo_axis),
      .out_axis(out_axis),
      .space(space),
      .occupied(occupied),
      .packet_count(packet_count)
      );

   
endmodule
  

                         






