//-------------------------------------------------------------------------------
// File:    axis_mm_to_pkt.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Depth of buffer FIFO
// * Maximum number of packets that can be concurrently buffered.
//
// Description:
// This module is a sink for DRaT formatted packets and enables them to be read via a
// 32bit AXI style CSR interface.
//
// Three register targets for reads are provided in the address map:
// UPPER  - Corresponds to [63:32] of packet word.
// LOWER  - Corresponds to [31:0] of packet word. Read triggers new bus beat and FIFO pop.
// STATUS - Packs: TLAST, VALID, Current Packet Occupancy, FIFO Occupancy
//
// The status register enables the internal packet FIFO's status to be polled including:
// Complete packets present.
// FIFO space occupied.
// Is the current FIFO tail a valid beat?
// Is the current FIFO tail the last beat of a packet?
//
// This is a simple block, it allows system level internal observability of the NoC.
// Reads from the LOWER trigger a FIFO pop action, thus UPPER should be read first, before LOWER.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_pkt_to_mm
  #(
    parameter FIFO_SIZE = 10,
    parameter MAX_PACKETS = 8
    )
   (
    input logic 	clk,
    input logic 	rst,
    //-------------------------------------------------------------------------------
    // CSR registers
    //-------------------------------------------------------------------------------
    output logic [31:0] upper,
    output logic [31:0] lower,
    input logic 	lower_pls,
    output logic [31:0] status,
    //-------------------------------------------------------------------------------
    // AXIS Input Bus
    //-------------------------------------------------------------------------------
    input logic [63:0] 	in_tdata,
    input logic 	in_tvalid,
    input logic 	in_tlast,
    output logic 	in_tready
    );

   logic [63:0] 	fifo_out_tdata;
   logic 		fifo_out_tvalid;
   logic 		fifo_out_tready;
   logic 		fifo_out_tlast;

   wire [15:0] 		occupied;
   wire [13:0] 		packet_count;



   assign status = {fifo_out_tlast,fifo_out_tvalid,packet_count,occupied};

   assign occupied[15:FIFO_SIZE+1] = 0;
   assign packet_count[13:MAX_PACKETS] = 0;

   assign upper = fifo_out_tdata[63:32];
   assign lower = fifo_out_tdata[31:0];
   assign fifo_out_tready = lower_pls;



   axis_packet_fifo
     #(
       .WIDTH(64),
       .SIZE(FIFO_SIZE),
       .MAX_PACKETS(MAX_PACKETS)
       )
   axis_packet_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .sw_rst(1'b0),
      // In
      .in_tdata(in_tdata),
      .in_tvalid(in_tvalid),
      .in_tready(in_tready),
      .in_tlast(in_tlast),
      // Out
      .out_tdata(fifo_out_tdata),
      .out_tvalid(fifo_out_tvalid),
      .out_tready(fifo_out_tready),
      .out_tlast(fifo_out_tlast),
      // Status
      .space(),
      .occupied(occupied[FIFO_SIZE:0]),
      .packet_count(packet_count[MAX_PACKETS-1:0])
      );

endmodule // axis_pkt_to_mm
