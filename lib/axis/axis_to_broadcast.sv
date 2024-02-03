//-----------------------------------------------------------------------------
// File:    axis_to_broadcast.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Convert backpressurable axis_t interface to axis_broadcast_t by removing tready
// in the downstream and forcing tready = 1 to the upstream.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_to_broadcast
  (
   axis_t.slave axis_in,
   axis_broadcast_t.master axis_out
   );
   

   always_comb
     begin
        axis_in.tready = 1'b1;
        axis_out.tdata = axis_in.tdata;
        axis_out.tvalid = axis_in.tvalid;
        axis_out.tlast = axis_in.tlast;
     end

endmodule // axis_to_broadcast
