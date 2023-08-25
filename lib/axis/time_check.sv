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
     input [63:0] current_time,
     // Time stamp to compare
     input [63:0] event_time,
     // Flags
     output logic early,
     output logic now,
     output logic late
     );

    //
    // Pure combinatorial evaluation
    // NOTE: Good chance will have to revisit this and make
    // pipelined logic to close high speed clock timing.
    //
    always_comb begin
        now = (current_time == event_time);
        late = (current_time > event_time);
        early = !now && !late;
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
     time_delta <= event_time - current_time;
      end
   end

     always_comb begin
     now = ~(|time_delta);
     late = time_delta[63];
     early = !now && !late;
   end
     */


endmodule // time_check
