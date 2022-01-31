//------------------------------------------------------------------------------
// File:    axis_mux4.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * arbitration scheme
//   - When in Round Robin mode, if current active port is N, then higest prioirty port for next transaction is (N+1) % 4.
//     Transactions can be back to back.
//   - When in Priority mode, always transition back to IDLE after a transaction and burn 1 cycle. Port 0 is highest priority.
// * buffer mode (included small FIFO)
// * Width of datapath.
//
// Description:
// 4 way AXI Stream mux with no combinatorial through paths.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_mux4
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
    // Input Bus 2
    //
    input logic [WIDTH-1:0]  in2_tdata,
    input logic 	     in2_tvalid,
    input logic 	     in2_tlast,
    output reg 		     in2_tready,
    //
    // Input Bus 3
    //
    input logic [WIDTH-1:0]  in3_tdata,
    input logic 	     in3_tvalid,
    input logic 	     in3_tlast,
    output reg 		     in3_tready,
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
   localparam INPUT0 = 2'b00;
   localparam INPUT1 = 2'b01;
   localparam INPUT2 = 2'b10;
   localparam INPUT3 = 2'b11;

   //
   // Enumerate States for arbitration.
   // These enumerations coded so LSB's drive mux.
   //
   localparam IDLE = 3'b100;
   localparam SELECT0 = 3'b000;
   localparam SELECT1 = 3'b001;
   localparam SELECT2 = 3'b010;
   localparam SELECT3 = 3'b011;

   reg [2:0] 		     arb_state;

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
	case(arb_state[1:0])
          INPUT0: begin
             in_tdata = in0_tdata;
             in_tvalid = in0_tvalid;
             in_tlast = in0_tlast;
             in0_tready = in_tready;
             in1_tready = 1'b0;
             in2_tready = 1'b0;
             in3_tready = 1'b0;
          end

          INPUT1: begin
             in_tdata = in1_tdata;
             in_tvalid = in1_tvalid;
             in_tlast = in1_tlast;
             in1_tready = in_tready;
             in0_tready = 1'b0;
             in2_tready = 1'b0;
             in3_tready = 1'b0;
          end

          INPUT2: begin
             in_tdata = in2_tdata;
             in_tvalid = in2_tvalid;
             in_tlast = in2_tlast;
             in2_tready = in_tready;
             in1_tready = 1'b0;
             in0_tready = 1'b0;
             in3_tready = 1'b0;
          end

          INPUT3: begin
             in_tdata = in3_tdata;
             in_tvalid = in3_tvalid;
             in_tlast = in3_tlast;
             in3_tready = in_tready;
             in1_tready = 1'b0;
             in2_tready = 1'b0;
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
             arb_state <= SELECT0;
           else if(in1_tvalid)
             arb_state <= SELECT1;
           else if(in2_tvalid)
             arb_state <= SELECT2;
           else if(in3_tvalid)
             arb_state <= SELECT3;

         SELECT0 :
           if(in_tready && in_tvalid && in_tlast)
             if(PRIORITY)
               arb_state <= IDLE;
             else if(in1_tvalid)
               arb_state <= SELECT1;
             else if(in2_tvalid)
               arb_state <= SELECT2;
             else if(in3_tvalid)
               arb_state <= SELECT3;
             else
               arb_state <= IDLE;

         SELECT1 :
           if(in_tready && in_tvalid && in_tlast)
             if(PRIORITY)
               arb_state <= IDLE;
             else if(in2_tvalid)
               arb_state <= SELECT2;
             else if(in3_tvalid)
               arb_state <= SELECT3;
             else if(in0_tvalid)
               arb_state <= SELECT0;
             else
               arb_state <= IDLE;

         SELECT2 :
           if(in_tready && in_tvalid && in_tlast)
             if(PRIORITY)
               arb_state <= IDLE;
             else if(in3_tvalid)
               arb_state <= SELECT3;
             else if(in0_tvalid)
               arb_state <= SELECT0;
             else if(in1_tvalid)
               arb_state <= SELECT1;
             else
               arb_state <= IDLE;

         SELECT3 :
           if(in_tready && in_tvalid && in_tlast)
             if(PRIORITY)
               arb_state <= IDLE;
             else if(in0_tvalid)
               arb_state <= SELECT0;
             else if(in1_tvalid)
               arb_state <= SELECT1;
             else if(in2_tvalid)
               arb_state <= SELECT2;
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

endmodule // axis_mux4
