//-----------------------------------------------------------------------------
// File:    axis_pkt_to_stream.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// This module is the root module of a subsystem that:
//  * Receives a DRaT packetized sample stream,
//  * Deframes it,
//  * Drives a sample oriented AXIS bus out.
//  * Provides (time) synchronous operation
//  * Can be used to build coherant Tx systems
//  * Handles and recovers from likely error scenarios
//  * Reports status and consumption via async packets
//  * Currently only supports COMPLEX16 data types
//  * Consumption report generation included but not mandated (can dissable)
//
// Un-answered questions:
//  * Exact details of DUC (Digital Up Converter) pipeline operation - Are strobes passed upstream from interpolation?
//  * Where should digital silence be inserted into DUC? Does it always run?
//
// Foreseeable features that may yet need to be implemented:
//  * Rate control for Consumption Packets so that packet rate to the sink is
//    bith timely but never overwhelming.
//  * Autmatic transfer of FlowID from axis_tx_control to axi_status_report_i/axi_consumption_report_i
//    such that it is derived from the arriving sample stream rather than programmed by the control plane.
//
// Signals that should be connected to CSR (Control/Status Registers) in upward heirarchy:
//  * deframer_enable_in, status_enable_in, consumption_enable_in, tx_control_enable_in
//      These are all module enable signals and should be R/W CSR bits.
//      They have use for: enabling optional features, reseting to known state,
//      idling logic during configuration changes.
//  * status_flow_id_in, consumption_flow_id_in
//      These allow the control plane to program the destination for Status and Consumtion packet flows
//      which might be the reverse of the sample flow or to a third party endpoint for control plane
//      logging or action trigger. These should be R/W registers.
//  * error_policy_next_packet_in - This control bit determines state machine actions to recover from errors
//      and should be a R/W register.
//  * run_out - This bit provides an indication of active normal operation and would make a valuable
//      RO status bit.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_pkt_to_stream

    (
     input logic        clk,
     input logic        rst,
     // System time in
     input logic [63:0] current_time_in,
     // Enable signals
     input logic        deframer_enable_in,
     input logic        status_enable_in,
     input logic        consumption_enable_in,
     input logic        tx_control_enable_in,
     // FlowID to me used in status packet header
     input logic [31:0] status_flow_id_in,
     // FlowID to me used in consumption packet header
     input logic [31:0] consumption_flow_id_in,
     // Error policy register
     input logic        error_policy_next_packet_in,
     // Flag Output beats that are active sample data vs zero padding
     output logic       run_out,
     // Dirt/DRat packetized stream in
     axis_t.slave axis_pkt_in,
     // Status pkt stream out
     axis_t.master axis_status_out,
     // Consumption pkt stream out
     axis_t.master axis_consumption_out,
     // Stream oriented raw IQ samples out
     axis_t.master axis_stream_out
     );

    import dirt_protocol::*;
    import axis_pkt_to_stream_pkg::*;

    // Width of FIFO passing unframed IQ samples plus metadata
    localparam C_FIFO_WIDTH = $bits(pkt_to_stream_fifo_t);

    // Time compare flags
    logic               late, now;

    // Payload for async STATUS packages.
    logic               generate_pkt;
    logic [63:0]        status_payload;

    // Consumption
    logic               generate_consumption;
    logic [7:0]         consumed_seq_num;

    // Local sample plus metadata buffer
    axis_t #(.WIDTH(C_FIFO_WIDTH)) axis_tail(.clk(clk));
    axis_t #(.WIDTH(C_FIFO_WIDTH)) axis_head(.clk(clk));


    //
    // Deframe packets here, place in short FIFO with metadata that can drive
    // output stream with consistant latency
    //
    axis_deframer axis_deframer_i (
                                   .clk(clk),
                                   .rst(rst),
                                   .enable_in(deframer_enable_in),
                                   .axis_pkt_in(axis_pkt_in),
                                   .axis_tail_out(axis_tail)
                                   );


    // FIFO buffers unframed samples plus associated state
    // Small FIFO, uses dist RAM.
    axis_fifo_wrapper  #(
                         .SIZE(5)
                         )
    axis_fifo_wrapper_i (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_tail),
                         .out_axis(axis_head)
                         );


    //
    // Drive output stream from here.
    // Can output IQ with zero clk delay (or enter error state).
    // Supplies payload beat to generate error status report packet.
    //
    axis_tx_control axis_tx_control_i (
                                       .clk(clk),
                                       .rst(rst),
                                       .enable_in(tx_control_enable_in),
                                       .error_policy_next_packet_in(error_policy_next_packet_in),
                                       .axis_head_in(axis_head),
                                       .now_in(now),
                                       .late_in(late),
                                       .generate_pkt_out(generate_pkt),
                                       .status_payload_out(status_payload),
                                       .generate_consumption_out(generate_consumption),
                                       .consumed_seq_num_out(consumed_seq_num),
                                       .run_out(run_out),
                                       .axis_stream_out(axis_stream_out)
                                       );

    //
    // Send status reports upstream
    //
    axis_status_report axis_status_report_i (
                                             .clk(clk),
                                             .rst(rst),
                                             .enable_in(status_enable_in),
                                             .flow_id_in(status_flow_id_in),
                                             .generate_pkt_in(generate_pkt),
                                             .status_payload_in(status_payload),
                                             .current_time_in(current_time_in),
                                             .axis_status_out(axis_status_out)
                                             );

    //
    // Send packet consumption reports upstream *FINISH!*
    //
    axis_status_report axis_consumption_report_i (
                                                  .clk(clk),
                                                  .rst(rst),
                                                  .enable_in(consumption_enable_in),
                                                  .flow_id_in(consumption_flow_id_in),
                                                  .generate_pkt_in(generate_consumption),
                                                  .status_payload_in({ACK,24'h0,consumed_seq_num}),
                                                  .current_time_in(current_time_in),
                                                  .axis_status_out(axis_consumption_out)
                                                  );


    //
    // Compare actual time to on-air time
    //
    time_check time_check_i (
                             .clk(clk),
                             .rst(rst),
                             .current_time_in(current_time_in),
                             .event_time_in(axis_head.tdata[127:64]),
                             .now_out(now),
                             .late_out(late)
                             );


endmodule // axis_pkt_to_stream
