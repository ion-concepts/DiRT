//-----------------------------------------------------------------------------
// File:    time_source.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
// 
// Real time clock for timestamping
//
// Description:
// A real time clock (RTC) that counts in a sample clock domain
// and who's output can be used to genereate meta-data timestamps for sample streams.
// The RTC simply counts clock edges and thus the quanta is determined by the input clock frequency.
// Applications may reference the count to a well defined Epoch by
// loading a counter value with a synchronization event.
//
// The control plane initialises this clock via CSR (Control/Status Register) writes.
// A new value to be loaded into the RTC is pre-loaded via 32bit CSR writes
// and a trigger then armed such that an event on an input signal triggers
// a time value transfer and clock update.
//
//
// The control plane can monitor the on going frequency of sync events by polling the
// event_time registers without rearming a time update.
// This can also be useful because the control plane can poll for a sync event related update
// and then know there is safe window of time to load a new time update value and arm for time update.
//
// control signals defined as follows:
// trigger_immediate_in - Trigger immmediate time update without corresponding event.
// sync0_enable_in - Set sync0 as a source of a time update event
// sync0_falling_in - 0=Rising Edge Event, 1=Falling Edge Event
// sync1_enable_in - Set sync1 as a source of a time update event
// sync1_falling_in - 0=Rising Edge Event, 1=Falling Edge Event
// set_time_high_in[31:0] - Write MSB's of new time value to load at trigger
// set_time_low_in[31:0] - Write LSB's of new time value to load at trigger
// control_event_in - Arming pulse for sync capture
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

`default_nettype none
module time_source
   (
    input wire          clk,
    input wire          rst,

    //
    // CSR interface
    //
    input wire [31:0]   set_time_high_in, // Assumed to be pre-loaded & stable before sync armed.
    input wire [31:0]   set_time_low_in, // Assumed to be pre-loaded & stable before sync armed.
    output logic [31:0] event_time_high_out,
    output logic [31:0] event_time_low_out,
    input wire          trigger_immediate_in,
    input wire          sync0_enable_in,
    input wire          sync0_falling_in,
    input wire          sync1_enable_in,
    input wire          sync1_falling_in,
    input wire          control_event_in, // Pulses one cycle asserted same cycle new data loaded in control.
    //
    // Event triggers
    //
    input wire          sync0_in,
    input wire          sync1_in,
    //
    // Timestamp output
    //
    output logic [63:0]  current_time_out
    );

    //
    // Maintain free running counter as RTC.
    // (Re)Load on armed and enabled sync events
    // Always caputre timestamps for sync events even when not armed.
    //
    wire                 trigger_event;
    wire                 sync0_edge;
    wire                 sync1_edge;

    always_ff @(posedge clk)
      if (rst) begin
          current_time_out <= 64'h0;
          {event_time_high_out,event_time_low_out} <= 64'h0;
      end else if (trigger_event) begin
          current_time_out <= {set_time_high_in,set_time_low_in};
          {event_time_high_out,event_time_low_out} <= {set_time_high_in,set_time_low_in}; // (Will be over written by next sync edge)
      end else begin
          current_time_out <= current_time_out + 1'b1;
          if (sync0_edge || sync1_edge) // Triggers every enabled sync edge so control plane can see sync events.
            {event_time_high_out,event_time_low_out} <= current_time_out + 1'b1;
      end

    //
    // Search for edge events on sync sources with programmed polarity
    // Trigger immediately if trigger_immediate_in is set
    //
    logic sync0_prev;
    logic sync1_prev;
    logic trigger_armed;

    always_ff @(posedge clk)
      if (rst) begin
          sync0_prev <= 1'b0;
          sync1_prev <= 1'b0;
      end else begin
          sync0_prev <= sync0_in;
          sync1_prev <= sync1_in;
      end

    assign sync0_edge = sync0_enable_in && (sync0_in ^ sync0_falling_in) && (!sync0_prev ^ sync0_falling_in);
    assign sync1_edge = sync1_enable_in && (sync1_in ^ sync1_falling_in) && (!sync1_prev ^ sync1_falling_in);
    assign trigger_event = (trigger_immediate_in || sync0_edge || sync1_edge) && trigger_armed;

    //
    // Anytime control is written it arms a time update on the next sync event
    //
    always_ff @(posedge clk)
      if (rst) begin
          trigger_armed <= 1'b0;
      end else if (control_event_in) begin
          trigger_armed <= 1'b1;
      end else if (trigger_event) begin
          trigger_armed <= 1'b0;
      end


endmodule
`default_nettype wire
