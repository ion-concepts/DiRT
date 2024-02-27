//------------------------------------------------------------------------------
// File:    axis_minimal_fifo.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Width of datapath.
//
// Description:
// AXI Stream interface ultra fast critical path FIFO.
// Only 2 entrys but no combinatorial feed through paths.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`default_nettype none
`include "global_defs.svh"

module axis_minimal_fifo
  #(
    parameter unsigned WIDTH=64 // AXIS datapath width.
    )

   (
    input wire               clk,
    input wire               rst,
    //
    // Input Bus
    //
    input wire [WIDTH-1:0]   in_tdata,
    input wire               in_tvalid,
    output logic             in_tready,
    //
    // Output Bus
    //
    output logic [WIDTH-1:0] out_tdata,
    output logic             out_tvalid,
    input wire               out_tready,
    //
    // Occupancy
    //
    output logic [1:0]       space,
    output logic [1:0]       occupied
    );

   logic [WIDTH-1:0]         data_reg1, data_reg2;

   logic [1:0]               state;

   localparam EMPTY = 0;
   localparam HALF = 1;
   localparam FULL = 2;

   always_ff @(posedge clk)
     if (rst) begin
        state <= EMPTY;
        out_tvalid <= 1'b0;
        in_tready <= 1'b1;
	space <= 2'h2;
	occupied <= 2'h0;
     end else begin
        case (state)
          // Nothing in either register.
          // Upstream can always push data to us.
          // Downstream has nothing to take from us.
          EMPTY: begin
             if (in_tvalid) begin
                state <= HALF;
                in_tready <= 1'b1;
                out_tvalid <= 1'b1;
		space <= 2'h1;
		occupied <= 2'h1;
             end else begin
                state <= EMPTY;
                in_tready <= 1'b1;
                out_tvalid <= 1'b0;
		space <= 2'h2;
		occupied <= 2'h0;
             end
          end
          // First Register Full.
          // Upstream can always push data to us.
          // Downstream can always read from us.
          HALF: begin
             if (in_tvalid && out_tready) begin
                state <= HALF;
                in_tready <= 1'b1;
                out_tvalid <= 1'b1;
		space <= 2'h1;
		occupied <= 2'h1;
             end else if (in_tvalid) begin
                state <= FULL;
                in_tready <= 1'b0;
                out_tvalid <= 1'b1;
		space <= 2'h0;
		occupied <= 2'h2;
             end else if (out_tready) begin
                state <= EMPTY;
                in_tready <= 1'b1;
                out_tvalid <= 1'b0;
		space <= 2'h2;
		occupied <= 2'h0;
             end else begin
                state <= HALF;
                in_tready <= 1'b1;
                out_tvalid <= 1'b1;
		space <= 2'h1;
		occupied <= 2'h1;
             end
          end // case: HALF
          // Both Registers Full.
          // Upstream can not push to us in this state.
          // Downstream can always read from us.
          FULL: begin
             if (out_tready) begin
                state <= HALF;
                in_tready <= 1'b1;
                out_tvalid <= 1'b1;
		space <= 2'h1;
		occupied <= 2'h1;
             end
             else begin
                state <= FULL;
                in_tready <= 1'b0;
                out_tvalid <= 1'b1;
		space <= 2'h0;
		occupied <= 2'h2;
             end
          end
        endcase // case(state)
     end // else: !if(rst)

   always_ff @(posedge clk) begin
      case (state)
        EMPTY: begin
            if (in_tvalid) begin
               data_reg1 <= in_tdata;
            end
        end
        HALF: begin
           if (in_tvalid && out_tready) begin
              data_reg1 <= in_tdata;
           end else if (in_tvalid) begin
              data_reg1 <= in_tdata;
              data_reg2 <= data_reg1;
           end
        end
      endcase
   end

   always_comb begin
      out_tdata = (state == FULL) ? data_reg2 : data_reg1;
   end

endmodule // axis_minimal_fifo

`default_nettype wire
