//------------------------------------------------------------------------------
// File:    axis_mux2_wrapper.sv
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
// Wrappers 2 way AXI Stream mux with no combinatorial through paths with System Vierlog AXIS bus interfaces.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
module axis_mux2_wrapper #(
        parameter BUFFER=0,  // Add small FIFO on egress.
        parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    ) (
        input logic clk,
        input logic rst,
        axis_t.slave in0_axis,
        axis_t.slave in1_axis,
        axis_t.master out_axis
    );

    logic [in0_axis.WIDTH-1:0] in0_tdata;
    logic                      in0_tvalid;
    logic                      in0_tlast;
    logic                      in0_tready;
    logic [in1_axis.WIDTH-1:0] in1_tdata;
    logic                      in1_tvalid;
    logic                      in1_tlast;
    logic                      in1_tready;
    logic [out_axis.WIDTH-1:0] out_tdata;
    logic                      out_tvalid;
    logic                      out_tlast;
    logic                      out_tready;

    always_comb begin
        in0_tdata       = in0_axis.tdata;
        in0_tvalid      = in0_axis.tvalid;
        in0_tlast       = in0_axis.tlast;
        in0_axis.tready = in0_tready;
        in1_tdata       = in1_axis.tdata;
        in1_tvalid      = in1_axis.tvalid;
        in1_tlast       = in1_axis.tlast;
        in1_axis.tready = in1_tready;
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_mux4 #(
        .WIDTH(out_axis.WIDTH),
        .BUFFER(BUFFER),
        .PRIORITY(PRIORITY)
    ) core (
        .clk(clk),
        .rst(rst),
        .in0_tdata(in0_tdata),
        .in0_tvalid(in0_tvalid),
        .in0_tlast(in0_tlast),
        .in0_tready(in0_tready),
        .in1_tdata(in1_tdata),
        .in1_tvalid(in1_tvalid),
        .in1_tlast(in1_tlast),
        .in1_tready(in1_tready),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_tready(out_tready)
    );
endmodule
