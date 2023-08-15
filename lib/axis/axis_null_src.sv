//-----------------------------------------------------------------------------
// File:    axis_null_src.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Perpetually idle AXIS bus master, drives all signals valid.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_null_src (
                      axis_t.master out_axis
                      );

    logic out_tready; // Discard
    //   
    always_comb begin
        out_axis.tdata  = 0;
        out_axis.tvalid = 0;
        out_axis.tlast  = 0;
        out_tready      = out_axis.tready;
    end
endmodule : axis_null_src
