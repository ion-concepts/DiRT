//----------------------------------------------------------------------------
// File:    dsp_loopback.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// To loop back TX to RX need to generate a strobe that defines the sample rate
// (i.e it qualifies the clk).
// Apply strobe to TREADY of TX and TVALID of RX. Ignore unused TVALID and TREADY.
//
// License: CERN-OHL-P (See LICENSE.md)
//-----------------------------------------------------------------------------


module dsp_loopback
  #(
    parameter COUNT_SIZE = 8
    )
  (
   input logic clk,
   input logic rst,
   // Sample stream in
   axis_t.slave axis_stream_in,
   // Sample stream out
   axis_t.master axis_stream_out
   );

   logic [COUNT_SIZE-1:0] count;
   logic                  strobe;
   logic [15:0]           sample;



   always_comb begin
      axis_stream_out.tdata = axis_stream_in.tdata;
      //axis_stream_out.tdata = {sample,sample};
      axis_stream_out.tvalid = strobe;
      axis_stream_in.tready = strobe;
   end


   // Evey time count wraps strobe is asserted for 1 cycle.
   always_ff @(posedge clk)
     if (rst) begin
        strobe <= 0;
        count <= 0;
     end else begin
        if (count == 0)
          strobe <= 1;
        else
          strobe <= 0;
        count <= count + 1;
     end
 
   // Every time count wraps strobe is asserted for 1 cycle.
/*
   always_ff @(posedge clk)
     if (rst) begin
        strobe <= 0;
        count <= 0;
        sample <= 0;
     end else begin
        if (count == 0) begin
           strobe <= 1;
           sample <= sample + 1;
        end else begin
          strobe <= 0;
        end
        count <= count + 1;
     end
*/
endmodule
