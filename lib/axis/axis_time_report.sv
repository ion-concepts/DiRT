//-----------------------------------------------------------------------------
// File:    axis_time_report.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// This module emits TIME_REPORT packets on demand.
// It maintains it's own Sequence Number counter. 
// FlowID is applied externally but should
// not be changed during operation, only when dissabled.
//
// A local counter triggers the emitance of a TIME REPORT at regular intervals,
// with programable frequency.
//
// Onward and external distribution, including possible multi or broadcast distribution
// is by means of the FlowID.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_time_report
  (
   input logic        clk,
   input logic        rst,
   // Remain quiescent in S_IDLE if not asserted.
   input logic        csr_enable,
   // Period in clock ticks between time reports.
   // Has built in multiply by 256
   input logic [15:0] csr_period,
   // FlowID to be used in status packet header
   input logic [31:0] csr_flow_id,
   // Current System Time
   input logic [63:0] current_time,
   // Dirt/DRat packetized stream out
   axis_t.master axis_time_out

   );
   import drat_protocol::*;


   // Length in bytes of a DRaT status packet
   localparam logic [15:0] C_TIME_PACKET_LENGTH = 16'd16;
   // DRaT packet type encoding
   localparam              pkt_type_t C_PKT_TYPE = TIME_REPORT;

   // States
   enum                    {
                            S_IDLE,
                            S_HEADER,
                            S_TIME
                            } state;

   logic [15:0]            counter;
   logic [7:0]             seq_num;
   logic                   generate_pkt;
   

   // Count down interval between TIME_REPORTs
   // Counter is initialized to 1 so that we can use simple equality test
   // to check for reset condition.
   always_ff @(posedge clk)
     if(rst) begin
        counter <= 16'd1;
        generate_pkt <= 1'b0;
     end else if (current_time[7:0] == 8'h00) begin
        if (counter == csr_period) begin
           generate_pkt <= 1'b1;
           counter <= 16'b1;
        end else begin
           counter <= counter + 1;
        end
     end else begin
       generate_pkt <= 1'b0;
     end

   // When not enabled, Seq Num will be reset.
   always_ff @(posedge clk)
     if(rst) begin
        seq_num <= 12'd0;
     end else if ((state == S_IDLE) && ~csr_enable) begin
        // Disabling block will reset Seq Num as it goes idle.
        seq_num <= 12'd0;
     end else if ((state == S_TIME) && axis_time_out.tready) begin
        seq_num <= seq_num + 12'd1;
     end

   always_ff @(posedge clk) begin
      if (rst) begin
         state <= S_IDLE;
      end else begin
         case (state)
           // Spin in this state until the generation of a packet is triggered.
           S_IDLE: begin
              if (generate_pkt && csr_enable)
                state <= S_HEADER;
           end
           // Generate DRaT TIME_REPORT Header beat
           S_HEADER: begin
              if (axis_time_out.tready)
                state <= S_TIME;
           end
           // Generate DRaT TIME_REPORT Timestamp beat
           S_TIME: begin
              if (axis_time_out.tready)
                state <= S_IDLE;
           end
         endcase // case (state)
      end // else: !if(rst)
   end

   // Mux different DRaT beats onto the bus.
   // (Note many of these paths pass through combinatorially.)
   always_comb begin
      axis_time_out.tvalid = (state != S_IDLE);
      axis_time_out.tlast = (state == S_TIME);
      case(state)
        S_HEADER  : axis_time_out.tdata = { C_PKT_TYPE, seq_num, C_TIME_PACKET_LENGTH, csr_flow_id };
        S_TIME    : axis_time_out.tdata = current_time; 
        default : axis_time_out.tdata = 64'd0; // Arbitrary default.
      endcase // case (state)
   end

endmodule 
