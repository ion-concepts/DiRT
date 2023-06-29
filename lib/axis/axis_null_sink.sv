//-----------------------------------------------------------------------------
// File:    axis_null_sink.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Accept all AXIS bus traffic and discard it.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`include "global_defs.svh"

module axis_null_sink (
                       axis_t.slave in_axis
                       );

    logic [63:0] in_tdata;
    logic        in_tvalid;
    logic        in_tlast;
    //   
    always_comb begin
        in_tdata = in_axis.tdata;
        in_tvalid = in_axis.tvalid;
        in_tlast = in_axis.tlast;
        in_axis.tready = 1;
    end
endmodule : axis_null_sink
