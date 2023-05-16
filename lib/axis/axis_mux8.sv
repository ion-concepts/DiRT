//------------------------------------------------------------------------------
// File:    axis_mux8.sv
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
// 8 way AXI Stream mux with no combinatorial through paths.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_mux8
  #(
    parameter WIDTH=64,  // AXIS datapath width.
    parameter BUFFER=0,  // Add small FIFO on egress.
    parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    )


   (
    input logic 	    clk,
    input logic 	    rst,
    //
    // Input Bus 0
    //
    input logic [WIDTH-1:0] in0_tdata,
    input logic 	    in0_tvalid,
    input logic 	    in0_tlast,
    output reg 		    in0_tready,
    //
    // Input Bus 1
    //
    input logic [WIDTH-1:0] in1_tdata,
    input logic 	    in1_tvalid,
    input logic 	    in1_tlast,
    output reg 		    in1_tready,
    //
    // Input Bus 2
    //
    input logic [WIDTH-1:0] in2_tdata,
    input logic 	    in2_tvalid,
    input logic 	    in2_tlast,
    output reg 		    in2_tready,
    //
    // Input Bus 3
    //
    input logic [WIDTH-1:0] in3_tdata,
    input logic 	    in3_tvalid,
    input logic 	    in3_tlast,
    output reg 		    in3_tready,
    //
    // Input Bus 4
    //
    input logic [WIDTH-1:0] in4_tdata,
    input logic 	    in4_tvalid,
    input logic 	    in4_tlast,
    output reg 		    in4_tready,
    //
    // Input Bus 5
    //
    input logic [WIDTH-1:0] in5_tdata,
    input logic 	    in5_tvalid,
    input logic 	    in5_tlast,
    output reg 		    in5_tready,
    //
    // Input Bus 6
    //
    input logic [WIDTH-1:0] in6_tdata,
    input logic 	    in6_tvalid,
    input logic 	    in6_tlast,
    output reg 		    in6_tready,
    //
    // Input Bus 7
    //
    input logic [WIDTH-1:0] in7_tdata,
    input logic 	    in7_tvalid,
    input logic 	    in7_tlast,
    output reg 		    in7_tready,
    //
    // Output Bus
    //
    output logic [WIDTH-1:0] out_tdata,
    output logic 	    out_tvalid,
    output logic 	    out_tlast,
    input logic 	    out_tready
    );

   //
   // Enumerate MUX control
   //
   localparam INPUT0 = 3'b000;
   localparam INPUT1 = 3'b001;
   localparam INPUT2 = 3'b010;
   localparam INPUT3 = 3'b011;
   localparam INPUT4 = 3'b100;
   localparam INPUT5 = 3'b101;
   localparam INPUT6 = 3'b110;
   localparam INPUT7 = 3'b111;

   //
   // Enumerate States for arbitration.
   // These enumerations coded so LSB's drive mux.
   //
   localparam IDLE = 4'b1000;
   localparam SELECT0 = 4'b0000;
   localparam SELECT1 = 4'b0001;
   localparam SELECT2 = 4'b0010;
   localparam SELECT3 = 4'b0011;
   localparam SELECT4 = 4'b0100;
   localparam SELECT5 = 4'b0101;
   localparam SELECT6 = 4'b0110;
   localparam SELECT7 = 4'b0111;

   reg [3:0]             arb_state;

   logic [WIDTH-1:0]    out_tdata_fifo;
   logic                  out_tlast_fifo;
   logic                  out_tvalid_fifo;
   logic                  out_tready_fifo;

   reg [WIDTH-1:0]     in_tdata;
   reg                   in_tvalid;
   reg                   in_tlast;
   logic                  in_tready;

   //
   // 8 way combinatorial mux of the different inputs.
   //
   always_comb
     begin
        // Use default values to reduce code size - (hopefully no timing hit due to crap synth tools.)
        in0_tready = 1'b0;
        in1_tready = 1'b0;
        in2_tready = 1'b0;
        in3_tready = 1'b0;
        in4_tready = 1'b0;
        in5_tready = 1'b0;
        in6_tready = 1'b0;
        in7_tready = 1'b0;

        case(arb_state[2:0])
          INPUT0: begin
             in_tdata = in0_tdata;
             in_tvalid = in0_tvalid;
             in_tlast = in0_tlast;
             in0_tready = in_tready;
          end

          INPUT1: begin
             in_tdata = in1_tdata;
             in_tvalid = in1_tvalid;
             in_tlast = in1_tlast;
             in1_tready = in_tready;
          end

          INPUT2: begin
             in_tdata = in2_tdata;
             in_tvalid = in2_tvalid;
             in_tlast = in2_tlast;
             in2_tready = in_tready;
          end

          INPUT3: begin
             in_tdata = in3_tdata;
             in_tvalid = in3_tvalid;
             in_tlast = in3_tlast;
             in3_tready = in_tready;
          end

          INPUT4: begin
             in_tdata = in4_tdata;
             in_tvalid = in4_tvalid;
             in_tlast = in4_tlast;
             in4_tready = in_tready;
          end

          INPUT5: begin
             in_tdata = in5_tdata;
             in_tvalid = in5_tvalid;
             in_tlast = in5_tlast;
             in5_tready = in_tready;
          end

          INPUT6: begin
             in_tdata = in6_tdata;
             in_tvalid = in6_tvalid;
             in_tlast = in6_tlast;
             in6_tready = in_tready;
          end

          INPUT7: begin
             in_tdata = in7_tdata;
             in_tvalid = in7_tvalid;
             in_tlast = in7_tlast;
             in7_tready = in_tready;
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
         IDLE : begin
            if(in0_tvalid)
              arb_state <= SELECT0;
            else if(in1_tvalid)
              arb_state <= SELECT1;
            else if(in2_tvalid)
              arb_state <= SELECT2;
            else if(in3_tvalid)
              arb_state <= SELECT3;
            else if(in4_tvalid)
              arb_state <= SELECT4;
            else if(in5_tvalid)
              arb_state <= SELECT5;
            else if(in6_tvalid)
              arb_state <= SELECT6;
            else if(in7_tvalid)
              arb_state <= SELECT7;
         end
         SELECT0 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else
                arb_state <= IDLE;
         end
         SELECT1 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else
                arb_state <= IDLE;
         end
         SELECT2 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else
                arb_state <= IDLE;
         end
         SELECT3 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else
                arb_state <= IDLE;
         end
         SELECT4 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else
                arb_state <= IDLE;
         end
         SELECT5 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else
                arb_state <= IDLE;
         end
         SELECT6 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in7_tvalid)
                arb_state <= SELECT7;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else
                arb_state <= IDLE;
         end
         SELECT7 : begin
            if(in_tready && in_tvalid && in_tlast)
              if(PRIORITY)
                arb_state <= IDLE;
              else if(in0_tvalid)
                arb_state <= SELECT0;
              else if(in1_tvalid)
                arb_state <= SELECT1;
              else if(in2_tvalid)
                arb_state <= SELECT2;
              else if(in3_tvalid)
                arb_state <= SELECT3;
              else if(in4_tvalid)
                arb_state <= SELECT4;
              else if(in5_tvalid)
                arb_state <= SELECT5;
              else if(in6_tvalid)
                arb_state <= SELECT6;
              else
                arb_state <= IDLE;
         end
         default : begin
            arb_state <= IDLE;
         end
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
