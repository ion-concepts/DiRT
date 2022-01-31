//----------------------------------------------------------------------------
// File:    axis_demux4.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Width of datapath.
//
// Description:
// The DEMUX burns 1 IDLE cycle minumum for every transaction.
// The DEMUX passes the initial line of the packet out (post-FIFO) as the header
// to be parsed by external combinatorial logic to generate the select signal.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`include "global_defs.svh"

module axis_demux4
  #(
    parameter unsigned WIDTH=64  // AXIS datapath width.
    )


   (
    input logic 		 clk,
    input logic 		 rst,
    //
    // External logic supplies egress port selection.
    //
    output logic [WIDTH-1:0] header,
    input logic [1:0] 	 select,
    //
    // Output Bus 0
    //
    output logic [WIDTH-1:0] out0_tdata,
    output logic 		 out0_tvalid,
    output logic 		 out0_tlast,
    input logic 		 out0_tready,
    //
    // Output Bus 1
    //
    output logic [WIDTH-1:0] out1_tdata,
    output logic 		 out1_tvalid,
    output logic 		 out1_tlast,
    input logic 		 out1_tready,
    //
    // Output Bus 2
    //
    output logic [WIDTH-1:0] out2_tdata,
    output logic 		 out2_tvalid,
    output logic 		 out2_tlast,
    input logic 		 out2_tready,
    //
    // Output Bus 3
    //
    output logic [WIDTH-1:0] out3_tdata,
    output logic 		 out3_tvalid,
    output logic 		 out3_tlast,
    input logic 		 out3_tready,
    //
    // Input Bus
    //
    input logic [WIDTH-1:0]  in_tdata,
    input logic 		 in_tvalid,
    input logic 		 in_tlast,
    output logic 		 in_tready
    );

   //
   // Enumerate MUX control
   //
   localparam OUTPUT0 = 2'b00;
   localparam OUTPUT1 = 2'b01;
   localparam OUTPUT2 = 2'b10;
   localparam OUTPUT3 = 2'b11;

   //
   // Enumerate states for mux selection.
   //
   localparam IDLE = 1'b0;
   localparam BUSY = 1'b1;

   reg                   state;



   logic [WIDTH-1:0] 	 in_tdata_fifo;
   logic 		 in_tlast_fifo;
   logic 		 in_tvalid_fifo;
   logic 		 in_tready_fifo;

   reg                   enable_ready;
   reg [1:0]             select_reg;

   //
   // State Machine
   //
   always_ff @(posedge clk)
     if(rst) begin
        state <= IDLE;
        enable_ready <= 1'b0;
        select_reg <= 2'b0;
     end
     else if (state == IDLE) begin // Explcit state == IDLE
        if (in_tvalid_fifo) begin
           select_reg <= select;
           enable_ready <= 1'b1;
           state <= BUSY;
        end
     end else begin //implicit state == BUSY
        if (in_tvalid_fifo & in_tready_fifo & in_tlast_fifo) begin
           state <= IDLE;
           enable_ready <= 1'b0;
        end
     end


   //
   // 4 way combinatorial mux of the different valid/ready pairs from outputs.
   //

   assign out0_tvalid = (select_reg == OUTPUT0) && enable_ready && in_tvalid_fifo;
   assign out1_tvalid = (select_reg == OUTPUT1) && enable_ready && in_tvalid_fifo;
   assign out2_tvalid = (select_reg == OUTPUT2) && enable_ready && in_tvalid_fifo;
   assign out3_tvalid = (select_reg == OUTPUT3) && enable_ready && in_tvalid_fifo;

   assign in_tready_fifo =
                          ((select_reg == OUTPUT0) && enable_ready && out0_tready) |
                          ((select_reg == OUTPUT1) && enable_ready && out1_tready) |
                          ((select_reg == OUTPUT2) && enable_ready && out2_tready) |
                          ((select_reg == OUTPUT3) && enable_ready && out3_tready);


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
      .out_tdata({in_tlast_fifo,in_tdata_fifo}),
      .out_tvalid(in_tvalid_fifo),
      .out_tready(in_tready_fifo),
      // Status (unused)
      .space(),
      .occupied()
      );

   assign header = in_tdata_fifo;

   //
   // Allow tdata and tlast to always propogate to all outputs directly
   //
   assign {out0_tlast,out0_tdata,out1_tlast,out1_tdata,out2_tlast,out2_tdata,out3_tlast,out3_tdata} = {4{in_tlast_fifo,in_tdata_fifo}};


endmodule // axis_demux4

