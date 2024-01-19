//------------------------------------------------------------------------------
// File:    axis_broadcast_to_fifo.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Size of main FIFO
// * Mitigate downstream congestion by dropping ingressing packets for which there is no room.
//
// Description:
// Bridges broadcast bus to regular FIFO interface for DRaT packets.
// Filter imports FlowID so that CSR support can be added.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"
`include "drat_protocol.sv"

module axis_broadcast_to_fifo
   #(
     parameter FIFO_SIZE=9,  // FIFO size in powers of 2.
     parameter MITIGATE_OVERFLOW = 0 // Drop packets when down stream FIFO space too small.
    )
   (
    input logic  clk,
    input logic  rst,
    input logic  sw_rst,
    //-------------------------------------------------------------------------------
    // AXIS Output Bus
    //-------------------------------------------------------------------------------
    axis_t.master out_axis,
    //-------------------------------------------------------------------------------
    // AXIS Input Bus
    //-------------------------------------------------------------------------------
    axis_broadcast_t.slave in_axis,
    //-------------------------------------------------------------------------------
    // Control & Status
    //-------------------------------------------------------------------------------
    output logic csr_overflow,
    input logic  csr_enable,
    drat_protocol::flow_id_t csr_flow_id,
    input logic  csr_match_src,
    input logic  csr_match_dst
    );
   
   import drat_protocol::*;
   
   logic [63:0]  header_in;
   
   logic           pass_in;

   axis_t #(.WIDTH(64)) axis_filter(.clk(clk));
   axis_t #(.WIDTH(64)) axis_fifo1(.clk(clk));
   axis_t #(.WIDTH(64)) axis_fifo2(.clk(clk));

   logic [FIFO_SIZE:0] space;

   //
   // Filter packets for a match of FLOW_ID and packet type
   //
   axis_filter
    #(
       .WIDTH(64)
       )
   axis_filter_i0
     (
      .clk(clk),
      .rst(rst),
      .sw_rst(sw_rst),
      //
      // External logic supplies filter logic
      //
      .header(header_in),
      .pass(pass_in),
      //
      // Output Bus
      //
      .out_axis(axis_filter),
      //
      // Input Bus
      //
      .in_axis(in_axis),
      //
      // Status Flags
      //
      .overflow(csr_overflow),
      //
      // Control
      //
      .enable(csr_enable)
      );

   // Filter based on packet src, destination and type...is it addressed to us, from whom we are interested in, and of type INT16_COMPLEX?
   generate
      if (MITIGATE_OVERFLOW) begin: mitigate_overflow
         always_comb begin
            // Trunctaing length LSB's so test for less than space in case there is a last beat with < 8 octets
            automatic drat_protocol::pkt_header_t header = drat_protocol::populate_header_no_timestamp(header_in);
            automatic logic        size_test;
            
            size_test = header.length[15:3] < space;

            pass_in = (header.packet_type == INT16_COMPLEX) &&
                      ((header.flow_id.flow_addr.flow_src == csr_flow_id.flow_addr.flow_src) || ~csr_match_src) &&
                      ((header.flow_id.flow_addr.flow_dst == csr_flow_id.flow_addr.flow_dst) || ~csr_match_dst) &&
                      size_test;
         end
      end else  begin: accept_overflow
         always_comb begin
            automatic drat_protocol::pkt_header_t header = drat_protocol::populate_header_no_timestamp(header_in);
            pass_in = (header.packet_type == INT16_COMPLEX) &&
                      ((header.flow_id.flow_addr.flow_src == csr_flow_id.flow_addr.flow_src) || ~csr_match_src) &&
                      ((header.flow_id.flow_addr.flow_dst == csr_flow_id.flow_addr.flow_dst) || ~csr_match_dst);
            
         end           
      end // block: mitigate_overflow
   endgenerate

   //-------------------------------------------------------------------------------
   // AXIS minimal FIFO breaks all combinatorial through paths
   //-------------------------------------------------------------------------------
   axis_minimal_fifo_wrapper input_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_filter),
      .out_axis(axis_fifo1),
      .space_out(),
      .occupied_out()
      );

   //-------------------------------------------------------------------------------
   // AXIS FIFO buffers packets.
   //-------------------------------------------------------------------------------
   axis_fifo_wrapper
     #(
       .SIZE(9),
       .ULTRA(0)
       )
   packet_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_fifo1),
      .out_axis(axis_fifo2),
      .space(space),
      .occupied()
      );

   //-------------------------------------------------------------------------------
   // AXIS minimal FIFO breaks all combinatorial through paths
   //-------------------------------------------------------------------------------
   axis_minimal_fifo_wrapper output_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_fifo2),
      .out_axis(out_axis),
      .space_out(),
      .occupied_out()
      );

endmodule //
