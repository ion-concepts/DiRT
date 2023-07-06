//-----------------------------------------------------------------------------
// File:    axis_concat_data.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// This is a combinatorial pass-through for any axis_t bus.
// It concatenates a 3rd party data bus to the exisiting AXIS TDATA on
// any cycle with TVALID == TREADY == TRUE
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`include "global_defs.svh"

module axis_concat_data
    #(
      parameter unsigned WIDTH=64  // Width of data to concat to AXIS bus
      )
    (
     input logic       clk,
     input logic       rst,
     //
     // Input Bus
     //
     axis_t.slave in_axis,
     //
     // Data bus to concat
     //
     logic [WIDTH-1:0] concat_data_in,
     //
     // Output Bus
     //
     axis_t.master out_axis,
     //
     // Enable
     //
     input logic       enable
     );


    always_comb begin
        out_axis.tdata = {concat_data_in,in_axis.tdata};
        out_axis.tvalid = in_axis.tvalid && enable;
        out_axis.tlast = in_axis.tlast;
        in_axis.tready = out_axis.tready && enable;
    end

endmodule
