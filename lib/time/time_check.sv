//------------------------------------------------------------------------------
// File:    time_check.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
//
// Description:
// Compare two 64bit time values and set early/now/late flags
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

module time_check
    (
     input logic  clk,
     input logic  rst,
     // Current system time
     input [63:0] current_time_in,
     // Time stamp to compare
     input [63:0] event_time_in,
     // Flags
     output logic early_out,
     output logic now_out,
     output logic late_out
     );

    //
    // Pure combinatorial evaluation
    // NOTE: Good chance will have to revisit this and make
    // pipelined logic to close high speed clock timing.
    //
    always_comb begin
        now_out = (current_time_in == event_time_in);
        late_out = (current_time_in > event_time_in);
        early_out = !now_out && !late_out;
    end

    //
    // 1 stage pipeline version
    // (NOTE: left this here in case it becomes apparent in early implementation we have timing closure issues)
    /*
     logic [63:0] time_delta;

     always_ff @(posedge clk) begin
     if (rst) begin
     time_delta <= 64'b0;
      end else begin
     time_delta <= event_time_in - current_time_in;
      end
   end

     always_comb begin
     now_out = ~(|time_delta);
     late_out = time_delta[63];
     early_out = !now_out && !late_out;
   end
     */


endmodule // time_check
