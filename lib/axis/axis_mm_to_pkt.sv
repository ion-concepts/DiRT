//-------------------------------------------------------------------------------
// File:    axis_mm_to_pkt.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Depth of buffer FIFO
//
// Description:
// This module takes a series of MM bus writes and constructs a buffered packet from them.
// Packets have a 64bit quanta, but the AXI CSR interface as implemented here is 32Bit.
// Three register targets for writes are provided in the address map:
// UPPER  - Corresponds to [63:32] of packet word.
// LOWER_NORM  - Corresponds to [31:0] of packet word. Write triggers bus beat.
// LOWER_LAST  - Corresponds to [31:0] of packet word. Write triggers bus beat with tlast set.
//
// In addition a read only status register is provided:
// STATUS  - Reads local FIFO space available to accomodate new bus beats.  
//
// This is a simple block, it allows system level internal controllability, for example allowing
// users to create malformed packets as part of the verification process
// Writes to either of the registers named LOWER triggers actions; A write to LOWER_NORM causes an output
// bus beat to be formed, a write to LOWER_LAST causes an output bus beat to be formed with TLAST asserted.
//
// Packets will not egress the block until a beat with TLAST has been formed defining the end of a packet,
// and interemdiate bus beats will accumulate in the local FIFO space. Local FIFO space availablilty can 
// be read at any time via the STATUS register.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_mm_to_pkt
  #(parameter FIFO_SIZE = 10)
  (
   input logic 	       clk,
   input logic 	       rst,
   //-------------------------------------------------------------------------------
   // CSR registers
   //-------------------------------------------------------------------------------
   input logic [31:0]  upper,
   input logic 	       upper_pls,
   input logic [31:0]  lower_norm,
   input logic 	       lower_norm_pls,
   input logic [31:0]  lower_last,
   input logic 	       lower_last_pls,
   output logic [31:0] status,
   //-------------------------------------------------------------------------------
   // AXIS Output Bus
   //-------------------------------------------------------------------------------
   output logic [63:0] out_tdata,
   output logic        out_tvalid,
   output logic        out_tlast,
   input logic 	       out_tready
   );

   logic [FIFO_SIZE:0] space;
   logic [63:0]        fifo_in_tdata;
   logic 	       fifo_in_tvalid;
   logic 	       fifo_in_tlast;
   logic 	       fifo_in_tready;
   

   // Size mismatch here, zero pad LSB's
   assign status[FIFO_SIZE:0] = space[FIFO_SIZE:0];
   assign status[30:FIFO_SIZE+1] = 0;
   assign status[31] = fifo_in_tready;
   
   
   // Back-to-back CSR writes could generate interesting corner cases but that should not be possible
   // externally.
   assign fifo_in_tvalid =  lower_norm_pls || lower_last_pls;
   assign fifo_in_tdata = lower_last_pls ? {upper,lower_last} : {upper,lower_norm} ;
   assign fifo_in_tlast = lower_last_pls;
   
   // Note currently no protection from overrunning.

   axis_packet_fifo
     #(
       .WIDTH(64),
       .SIZE(FIFO_SIZE),
       .MAX_PACKETS(8)
       )
   axis_packet_fifo_i0
     (
      .clk(clk), 
      .rst(rst),
      .sw_rst(1'b0),
      // In
      .in_tdata(fifo_in_tdata), 
      .in_tvalid(fifo_in_tvalid), 
      .in_tready(fifo_in_tready),
      .in_tlast(fifo_in_tlast),
      // Out
      .out_tdata(out_tdata), 
      .out_tvalid(out_tvalid), 
      .out_tready(out_tready),
      .out_tlast(out_tlast),
      // Status
      .space(space), 
      .occupied(),
      .packet_count()
      );
   
endmodule // axis_mm_to_pkt

