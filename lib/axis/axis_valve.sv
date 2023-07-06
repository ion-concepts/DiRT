//-----------------------------------------------------------------------------
// File:    axis_valve.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Combinatorial pass through for any axis_t bus.
// Enable signal gates the handshaking.
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
module axis_valve (
                   input logic clk,
                   input logic rst,
                   //
                   // Input Bus
                   //
                   axis_t.slave in_axis,
                   //
                   // Output Bus
                   //
                   axis_t.master out_axis,
                   //
                   // Enable
                   //
                   input logic enable
                   );


    always_comb begin
        out_axis.tdata = in_axis.tdata;
        out_axis.tvalid = in_axis.tvalid && enable;
        out_axis.tlast = in_axis.tlast;
        in_axis.tready = out_axis.tready && enable;
    end

endmodule
