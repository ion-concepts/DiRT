//-----------------------------------------------------------------------------
// File:    axis_flow_control_time.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// This module provides a source of credit based flow control for a DRaT packet flow.
// Rather than being driven by a credit release from the flow sink, credit is implicitly released through
// the advance of the systemwide time value because packets are consumed at a known and
// constant rate (Normally by a downstream DUC/DAC chain).
//
// The total system must know the following to maintain correct buffer fullness:
// * Total dedicated elastic buffering for this flow
// * Downstream Sampling rate (Sample consumption rate)
//
// However the control plane can reduce this to a simple delta in time between current system time
// and a "release" time that passes packets through this block ahead of there scheduled presentation time downstream.
// Thus this block in the dataplane needs only to be programmed with this time delta and have a
// feed of the system time value, presentation time being embeded in packet headers arriving from the upstream.
//
// The total downstream elastic buffering provided should be exclusive for this traffic flow and should provide for:
// * Transport jitter masking
//   (Traffic congestion and switching pre-emption is an important system behavior here)
// * Granularity of credit release
// * MTU of packets
// * The typical in flight latency for the end-to-end transport
//   (Because this much data will typically be unavailable in the buffer to mitigate the above)
//
// Programming interface:
// enable_in - Set to enable operation.
// time_delta_in [31:0] - Delta from current system time to release packets to downstream.
//
// License: CERN-OHL-P (See LICENSE.md)
// 
//-----------------------------------------------------------------------------
`default_nettype none

module axis_flow_control_time
  (
   input wire        clk,
   input wire        rst,
   // Control/Status Register interface
   input wire        csr_enable,
   input wire [31:0] csr_time_delta,
   // Current System Time
   input wire [63:0] system_time,
   // Upstream packet flow in
   axis_t.slave axis_in,
   // Downstream packet flow out
   axis_t.master axis_out
   );

   // AXIS bus between minimal FIFO and state machine that gates packet egress
   axis_t axis_fifo(.clk(clk));

   // Holding registers for header fields
   logic [63:0]      header_reg;
   logic [63:0]      timestamp_reg;

   //
   // Calculate time release threshold using system time + time delta
   //
   logic [63:0]      release_time;
   
   always_ff @(posedge clk) begin
      if (rst) begin
         release_time <= 64'd0;
      end else begin
         release_time <= system_time + csr_time_delta;
      end
   end
   
   //
   // Minimal sized FIFO used to break any combinatorial feed through paths.
   // Place close to ingress.
   //
   axis_minimal_fifo_wrapper axis_minimal_fifo_wrapper_i
     (
      .clk(clk),
      .rst(rst),
      // Input Bus
      .in_axis(axis_in),
      // Output Bus
      .out_axis(axis_fifo),
      // Occupancy
      .space_out(),
      .occupied_out()
      );


   //
   // State Machine tracks DRaT packets passing by
   //
   enum {
         S_HEAD_IN,
         S_TIME_IN,
         S_WAIT,
         S_HEAD_OUT,
         S_TIME_OUT,
         S_PAYLOAD
         } state;

   always_ff @(posedge clk) begin
      if (rst) begin
         header_reg <= 64'd0;
         timestamp_reg <= 64'd0;
         state <= S_HEAD_IN;
      end else begin
         // Defaults
         // End defaults.
         case (state)
           //
           // In the S_HEAD_IN state we search for the header beat of a packet
           // which should be the first beat after a beat with asserted TLAST 
           // (or after rst deassertion)
           //
           S_HEAD_IN: begin
              if (axis_fifo.tvalid) begin
                 // Place header beat into holding register
                 header_reg <= axis_fifo.tdata;
                 state <= S_TIME_IN;
              end
           end
           // 
           // In the S_TIME_IN state we search for the timestamp beat of a packet
           // which should be the second beat, ie following the header.
           //   
           S_TIME_IN: begin
              if (axis_fifo.tvalid) begin
                 // Place timestamp beat into holding register
                 // (Primarily so that timing closure is easier)
                 timestamp_reg <= axis_fifo.tdata;
                 state <= S_WAIT;
              end 
           end
           //
           // In the S_WAIT state we compare the timestamp_reg with
           // current system time offset by the time_delta.
           // If timestamp_reg is greater than that value then
           // release the packet for egress.
           // Assert TVALID to egress at this transition.
           //
           S_WAIT: begin
              if (timestamp_reg < release_time) begin
                 state <= S_HEAD_OUT;
              end
           end
           //
           // In the S_HEAD_OUT state, the holding reg for the header is muxed out onto the egress
           // AXIS bus.
           //
           S_HEAD_OUT: begin
              if (axis_out.tready) begin
                 state <= S_TIME_OUT;
              end
           end 
           //
           // In the S_TIME_OUT state, the holding reg for the timestamp is muxed out onto the egress
           // AXIS bus.
           //
           S_TIME_OUT: begin
              if (axis_out.tready) begin
                 state <= S_PAYLOAD;
              end
           end               
           // 
           // In the S_PAYLOAD state we search for an asserted TLAST
           // which signals the last beat of a packet.
           //
           S_PAYLOAD: begin
              if (axis_fifo.tvalid && axis_fifo.tlast && axis_out.tready) begin
                 // Timestamp beat passes by this cycle.
                 state <= S_HEAD_IN;
              end
           end
         endcase
      end // else: !if(rst)
   end // always_ff @ (posedge clk)

   always_comb begin
      unique case(state)
        S_HEAD_IN: axis_fifo.tready = 1'b1;
        S_TIME_IN: axis_fifo.tready = 1'b1;
        S_PAYLOAD: axis_fifo.tready = axis_out.tready;
        default: axis_fifo.tready = 1'b0;
      endcase // unique case (state)
   end

   //
   // MUX 3 different sources for TDATA field in Egress.
   //
   always_comb begin
      unique case(state)
        S_HEAD_IN: begin
           axis_out.tdata = axis_fifo.tdata;
           axis_out.tlast =  axis_fifo.tlast;
           axis_out.tvalid = 1'b0;
        end
        S_TIME_IN: begin
           axis_out.tdata = axis_fifo.tdata;
           axis_out.tlast =  axis_fifo.tlast;
           axis_out.tvalid = 1'b0;
        end
        S_HEAD_OUT: begin
           axis_out.tdata = header_reg;
           axis_out.tlast = 1'b0;
           axis_out.tvalid = 1'b1;
        end
        S_TIME_OUT: begin
           axis_out.tdata = timestamp_reg;
           axis_out.tlast = 1'b0;
           axis_out.tvalid = 1'b1;
        end
        S_WAIT: begin
           axis_out.tdata = header_reg;
           axis_out.tlast = 1'b0;
           axis_out.tvalid = 1'b0;
        end
        
        default: begin
           axis_out.tdata = axis_fifo.tdata;
           axis_out.tlast = axis_fifo.tlast;
           axis_out.tvalid = axis_fifo.tvalid;
        end
      endcase // case (state)
   end // always_comb
   
   
   
endmodule // axis_flow_control_time

`default_nettype wire
