//-------------------------------------------------------------------------------
// File:    axis_fifo_wrapper.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Parameterizable:
//
// * Size (Depth) of FIFO
// * FPGA vendor {xilinx|altera}
//
// Description:
// 
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
module axis_fifo_wrapper #(
        parameter SIZE=5, // 2^SIZE
        parameter VENDOR="xilinx",
        parameter ULTRA=0
    ) (
        input wire               clk,
        input wire               rst,
        // Input Bus
        axis_t.slave in_axis,
        // Output bus
        axis_t.master out_axis,
        // Debug
        output logic [SIZE:0]    space,
        output logic [SIZE:0]    occupied
    );

    logic [in_axis.WIDTH-1:0]  in_tdata;
    logic                      in_tvalid;
    logic                      in_tlast;
    logic                      in_tready;
    logic [out_axis.WIDTH-1:0] out_tdata;
    logic                      out_tvalid;
    logic                      out_tlast;
    logic                      out_tready;

    always_comb begin
        in_tdata        = in_axis.tdata;
        in_tvalid       = in_axis.tvalid;
        in_tlast        = in_axis.tlast;
        in_axis.tready  = in_tready;
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_fifo #(
        .WIDTH(in_axis.WIDTH + 1),
        .SIZE(SIZE),
        .VENDOR(VENDOR),
        .ULTRA(ULTRA)
    ) axis_fifo_i0 (
        .clk(clk),
        .rst(rst),
        .in_tdata({in_tlast, in_tdata}),
        .in_tvalid(in_tvalid),
        .in_tready(in_tready),
        .out_tdata({out_tlast, out_tdata}),
        .out_tvalid(out_tvalid),
        .out_tready(out_tready),
        .space(space),
        .occupied(occupied)
    );
   
endmodule
