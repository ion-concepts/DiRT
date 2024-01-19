//------------------------------------------------------------------------------
// File:    axis_filter.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
//
// Parse AXI Stream header and drop/pass packet on basis of externally generated signal.
//
//  Parameterizable: None
//
//  Needs to be capable of sustained operation with no idle cycles on the
//  input bus to support possible use of a broadcast bus with no back-pressure (No tready).
//
//  Current header to pass external loop for filter logic is combinatorial (revisit to pipeline!)
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_filter
    #(
      parameter WIDTH=64  // AXIS datapath width.
      )
   (
    input logic            clk,
    input logic            rst,
    input logic            sw_rst,
    //-------------------------------------------------------------------------------
    // External logic supplies filter logic
    //-------------------------------------------------------------------------------
    output logic [WIDTH-1:0] header,
    input logic            pass,
    //-------------------------------------------------------------------------------
    // AXIS Output Bus
    //-------------------------------------------------------------------------------
    axis_t.master out_axis,
    //-------------------------------------------------------------------------------
    // AXIS Input Bus
    //-------------------------------------------------------------------------------
    axis_broadcast_t.slave in_axis,
    //-------------------------------------------------------------------------------
    // Status Flags
    //-------------------------------------------------------------------------------
    output logic          overflow,
    //-------------------------------------------------------------------------------
    // Control
    //-------------------------------------------------------------------------------
    input logic            enable
    );

   axis_t #(.WIDTH(WIDTH)) in_pipe1_axis(.clk(clk));
   axis_t #(.WIDTH(WIDTH)) in_pipe2_axis(.clk(clk));

   //-------------------------------------------------------------------------------
   // Enumerate states for inter-packet gap detetecion.
   //-------------------------------------------------------------------------------
   enum {
         BETWEEN_PACKETS,
         IN_PACKET
         } ipg_state;
   
   //-------------------------------------------------------------------------------
   // Inter-Packet Gap State Machine -
   //
   // Constantly monitor broadcast bus after H/W reset so that
   // we are able to deduce from the main state machine when we are mid-packet
   // on the broadcast bus.
   //-------------------------------------------------------------------------------
   always_ff @(posedge clk)
     if (rst)
       ipg_state <=  BETWEEN_PACKETS;
     else if (ipg_state == BETWEEN_PACKETS)
       // State is BETWEEN_PACKETS
       if (in_pipe1_axis.tlast && in_pipe1_axis.tvalid)
         ipg_state <= BETWEEN_PACKETS;
       else if (in_pipe1_axis.tvalid)
         ipg_state <= IN_PACKET;
       else
         ipg_state <= BETWEEN_PACKETS;
     else
       // State is IN_PACKET
       if (in_pipe1_axis.tlast && in_pipe1_axis.tvalid)
         ipg_state <= BETWEEN_PACKETS;
       else
         ipg_state <= IN_PACKET;



   //-------------------------------------------------------------------------------
   // Enumerate States for main filter state machine
   //-------------------------------------------------------------------------------
   enum {
         IDLE,
         FILTER,
         PASS_PKT,
         DISCARD_PKT,
         DISABLED
         } filter_state;
   
   logic push;
   logic not_overflow;


   // Create nice alias for pipelined tdata for port export.
   always_comb begin
      header = in_pipe1_axis.tdata;
   end

   //
   // Always grab all AXIS signals every clock cycle unconditionally.
   // We have no ability to back-pressure the broadcast.
   // Pipeline everything to maximize clock speed.
   //
   always_ff @(posedge clk)
     if (rst) begin
        in_pipe1_axis.tdata <= ({WIDTH{1'b0}});
        in_pipe1_axis.tvalid <= 1'b0;
        in_pipe1_axis.tlast <= 1'b0;
     end else if (sw_rst) begin
        in_pipe1_axis.tdata <= {WIDTH{1'b0}};
        in_pipe1_axis.tvalid <= 1'b0;
        in_pipe1_axis.tlast <= 1'b0;
     end else begin
        in_pipe1_axis.tdata <= in_axis.tdata;
        in_pipe1_axis.tvalid <= in_axis.tvalid;
        in_pipe1_axis.tlast <= in_axis.tlast;
     end

   //
   // Second pipe stage always grabs pipe1.
   //
   always_ff @(posedge clk)
     if (rst) begin 
        in_pipe2_axis.tdata <= ({WIDTH{1'b0}});
        in_pipe2_axis.tvalid <= 1'b0;
        in_pipe2_axis.tlast <= 1'b0;
     end else if (sw_rst) begin
        in_pipe2_axis.tdata <= ({WIDTH{1'b0}});
        in_pipe2_axis.tvalid <= 1'b0;
        in_pipe2_axis.tlast <= 1'b0;
     end else begin
        in_pipe2_axis.tdata <= in_pipe1_axis.tdata;
        in_pipe2_axis.tvalid <= in_pipe1_axis.tvalid;
        in_pipe2_axis.tlast <= in_pipe1_axis.tlast;
     end

   //
   // Control State Machine
   //
   always_ff @(posedge clk)     
     if (rst) begin
        filter_state <= DISABLED;
     end else if (sw_rst) begin
        filter_state <= DISABLED;
     end else begin
        case(filter_state)
          //
          // The first cycle that tvalid_pipe1 is asserted in this state is assumed to indicate the bus beat containing the packet header.
          //
          IDLE: begin
             if (in_pipe1_axis.tvalid && pass)
               filter_state <= PASS_PKT;
             else if (in_pipe1_axis.tvalid)
               filter_state <= DISCARD_PKT;
             else
               filter_state <= IDLE;
          end
          //
          // Pass this packet, it passed the filter.
          // Header of packet in pipe2 as we transition into this state.
          // tlast asserted in pipe2 as we transition out of this state.
          // Direct entry to new PASS_PKT or DISCARD_PKT states possible for back-to-back packets.
          //
          PASS_PKT: begin
             if (in_pipe2_axis.tlast && in_pipe2_axis.tvalid) begin
                if (in_pipe1_axis.tvalid && pass) // Back-to-back pass packet case.
                  filter_state <= PASS_PKT;
                else if (in_pipe1_axis.tvalid)    // Back-to-back discard packet case.
                  filter_state <= DISCARD_PKT;
                else                         // Gap between packets.
                  filter_state <= IDLE;
             end else
               filter_state <= PASS_PKT;

          end
          //
          // Discard this packet, it failed the filter.
          // Header of packet in pipe2 as we transition into this state.
          // tlast asserted in pipe2 as we transition out of this state.
          // If enable has been de-asserted as we leave this state then transition to DISABLED else
          // direct entry to new PASS_PKT or DISCARD_PKT states possible for back-to-back packets.
          //
          DISCARD_PKT: begin
             if (in_pipe2_axis.tlast && in_pipe2_axis.tvalid) begin
                if (!enable)
                  filter_state <= DISABLED;
                else if (in_pipe1_axis.tvalid && pass)
                  filter_state <= PASS_PKT;
                else if (in_pipe1_axis.tvalid)
                  filter_state <= DISCARD_PKT;
                else
                  filter_state <= IDLE;
             end else
               filter_state <= DISCARD_PKT;
          end // case: DISCARD_PKT
          //
          // Filter is disabled in this state and all ingressing packets are discarded.
          // We transition out of this state when both the enable signal is asserted and
          // we see an asserted tlast signal so that we know when a new packet might start.
          //
          DISABLED: begin
             if (ipg_state==BETWEEN_PACKETS) begin
                if (!enable)
                  filter_state <= DISABLED;
                else if (in_pipe1_axis.tvalid && pass)
                  filter_state <= PASS_PKT;
                else if (in_pipe1_axis.tvalid)
                  filter_state <= DISCARD_PKT;
                else
                  filter_state <= IDLE;
             end else
               filter_state <= DISABLED;
          end // case: DISABLED

          default: begin
             filter_state <= DISABLED;
          end

        endcase // case (filter_state)
     end // else: !if(rst)

   //
   // Output FIFO
   // Generates full downstream handshaking again for AXIS.
   // Decouples downstream from need to accept back-to-back packets.
   // Provides way to detect overflow
   //
   logic [out_axis.WIDTH-1:0] out_tdata;
   logic                      out_tvalid;
   logic                      out_tlast;
   logic                      out_tready;
   
   always_comb
     begin
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
        push = (filter_state == PASS_PKT) && in_pipe2_axis.tvalid;
        overflow = ~not_overflow;
     end

   // Distributed RAM FIFO.
   axis_fifo
     #(.WIDTH(WIDTH+1),
       .SIZE(5))
   axis_fifo_i0
     (.clk(clk), 
      .rst(rst),
      .in_tdata({in_pipe2_axis.tlast,in_pipe2_axis.tdata}), 
      .in_tvalid(push),
      .in_tready(not_overflow), 
      .out_tdata({out_tlast,out_tdata}), 
      .out_tvalid(out_tvalid), 
      .out_tready(out_tready),
      .space(), 
      .occupied());


 

   


endmodule // axis_filter
