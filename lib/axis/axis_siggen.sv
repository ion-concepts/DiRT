//-----------------------------------------------------------------------------
// File:    axis_siggen.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Simple signal generator for test and verification purposes.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_siggen
    (
     input              clk,
     input              rst,
     // Control/Status Regs (CSRs)
     input logic        enable_in,
     input logic [31:0] phase_inc_in,
     input logic [7:0]  waveform_in,
     // Waveform output
     axis_t.master axis_stream_out
     );
    
    import axis_siggen_pkg::*;
    //
    // Phase Accumulator
    //
    logic [31:0]        phase;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            phase <= 32'd0;
        end else if (~enable_in) begin
            phase <= 32'd0;
        end else if (axis_stream_out.tready) begin 
            phase <= phase + phase_inc_in;
        end
    end

    always_ff @(posedge clk) begin
         if (rst) begin
             axis_stream_out.tdata[31:16] <= 16'd0;
             axis_stream_out.tdata[15:0] <= 16'd0;
             axis_stream_out.tvalid <= 1'b0;
             axis_stream_out.tlast <= 1'b0;
         end else begin
             axis_stream_out.tvalid <= 1'b1;
             axis_stream_out.tlast <= 1'b0;
             case(waveform_in)
                 axis_siggen_pkg::SQUAREWAVE: begin
                     // I
                     axis_stream_out.tdata[31:16] <= phase[31] ? 16'h8001 : 16'h7fff;
                     // Q (Pi/4 offset in phase)
                     axis_stream_out.tdata[15:0] <= phase[31] ^ phase[30] ?  16'h8001 : 16'h7fff;
                 end
                 axis_siggen_pkg::RAMP: begin
                     // I
                     axis_stream_out.tdata[31:16] <= phase[31:16];
                     // Q (Pi/4 offset in phase)
                     axis_stream_out.tdata[15:0] <= phase[31:16] + 16'h4000;
                 end
                 default: begin
                     
                     axis_stream_out.tdata[31:16] <= 16'd0;
                     axis_stream_out.tdata[15:0] <= 16'd0;
                 end
             endcase // case (waveform_in)
         end // else: !if(rst)
    end // always_ff @ (posedge clk)


endmodule // axis_siggen
