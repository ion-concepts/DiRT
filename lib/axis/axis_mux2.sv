//------------------------------------------------------------------------------
// File:    axis_mux2.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * arbitration scheme
//   - When in Round Robin mode, if current active port is N, then higest priorty port for next transaction is (N+1) % 2.
//     Transactions can be back to back.
//   - When in Priority mode, always transition back to IDLE after a transaction and burn 1 cycle. Port 0 is highest priority.
// * buffer mode (included small FIFO)
// * Width of datapath.
//
// Description:
// 2 way AXI Stream mux with no combinatorial through paths.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_mux2
  #(
    parameter WIDTH=64,  // AXIS datapath width.
    parameter BUFFER=0,  // Add small FIFO on egress.
    parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    )


   (
    input logic 	     clk,
    input logic 	     rst,
    //
    // Input Bus 0
    //
    input logic [WIDTH-1:0]  in0_tdata,
    input logic 	     in0_tvalid,
    input logic 	     in0_tlast,
    output reg 		     in0_tready,
    //
    // Input Bus 1
    //
    input logic [WIDTH-1:0]  in1_tdata,
    input logic 	     in1_tvalid,
    input logic 	     in1_tlast,
    output reg 		     in1_tready,
    //
    // Output Bus
    //
    output logic [WIDTH-1:0] out_tdata,
    output logic 	     out_tvalid,
    output logic 	     out_tlast,
    input logic 	     out_tready
    );

   //
   // Enumerate MUX control
   //
   localparam INPUT0 = 1'b0;
   localparam INPUT1 = 1'b1;

   //
   // Enumerate States for arbitration.
   // These enumerations coded so LSB's drive mux.
   //
   localparam IDLE = 2'b10;
   localparam SELECT0 = 2'b00;
   localparam SELECT1 = 2'b01;

   reg [1:0] 		     arb_state;

   logic [WIDTH-1:0] 	     out_tdata_fifo;
   logic 		     out_tlast_fifo;
   logic 		     out_tvalid_fifo;
   logic 		     out_tready_fifo;

   reg [WIDTH-1:0] 	     in_tdata;
   reg 			     in_tvalid;
   reg 			     in_tlast;
   logic 		     in_tready;

   //
   // 4 way combinatorial mux of the different inputs.
   //
   always_comb
     begin
	case(arb_state[0])
          INPUT0: begin
             in_tdata = in0_tdata;
             in_tvalid = in0_tvalid;
             in_tlast = in0_tlast;
             in0_tready = in_tready;
             in1_tready = 1'b0;
          end

          INPUT1: begin
             in_tdata = in1_tdata;
             in_tvalid = in1_tvalid;
             in_tlast = in1_tlast;
             in1_tready = in_tready;
             in0_tready = 1'b0;
          end

        endcase // case (select)
     end // always (*)



   //
   //  Arbitration State Machine.
   //
   always_ff @(posedge clk)
     if(rst)
       arb_state <= IDLE;
     else
       case (arb_state)
         IDLE :
           if(in0_tvalid)
             // Go to SELECT0 state unless this is a single-beat packet whose
             // beat is accepted in this cycle (when state is IDLE,
             // in0_tready = in_tready).
             arb_state <= in_tready && in0_tlast ? IDLE : SELECT0;
           else if(in1_tvalid)
             arb_state <= SELECT1;

         SELECT0 :
           if(in_tready && in_tvalid && in_tlast)
             if(PRIORITY)
               arb_state <= IDLE;
             else if(in1_tvalid)
               arb_state <= SELECT1;
             else
               arb_state <= IDLE;

         SELECT1 :
           if(in_tready && in_tvalid && in_tlast)
             if(PRIORITY)
               arb_state <= IDLE;
             else if(in0_tvalid)
               arb_state <= SELECT0;
             else
               arb_state <= IDLE;

         default :
           arb_state <= IDLE;
       endcase // case (arb_state)


   //
   // AXI minimal FIFO breaks all combinatorial through paths
   //
   axis_minimal_fifo #(.WIDTH(WIDTH+1)) axis_minimal_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_tdata({in_tlast,in_tdata}),
      .in_tvalid(in_tvalid),
      .in_tready(in_tready),
      .out_tdata({out_tlast_fifo,out_tdata_fifo}),
      .out_tvalid(out_tvalid_fifo),
      .out_tready(out_tready_fifo),
      // Status (unused)
      .space(),
      .occupied()
      );

   //
   // Optional small egress buffer FIFO to mitigate bursty contention.
   //
   generate
      if(BUFFER == 0)
        begin
           assign out_tdata = out_tdata_fifo;
           assign out_tlast = out_tlast_fifo;
           assign out_tvalid = out_tvalid_fifo;
           assign out_tready_fifo = out_tready;
        end
      else
        axis_fifo #(.WIDTH(WIDTH+1)) axis_fifo_short_i0
          (.clk(clk), .rst(rst),
           .in_tdata({out_tlast_fifo,out_tdata_fifo}), .in_tvalid(out_tvalid_fifo), .in_tready(out_tready_fifo),
           .out_tdata({out_tlast,out_tdata}), .out_tvalid(out_tvalid), .out_tready(out_tready),
           .space(), .occupied());
   endgenerate

endmodule // axis_mux2
