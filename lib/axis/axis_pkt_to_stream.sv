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
     input logic [63:0] current_time,
     // Enable signals
     input logic        deframer_enable,
     input logic        status_enable,
     input logic        consumption_enable,
     input logic        tx_control_enable,
     // Interval between consumption packets
     input logic [7:0]  consumption_period,
     // FlowID to me used in status packet header
     input logic [31:0] status_flow_id,
     // FlowID to me used in consumption packet header
     input logic [31:0] consumption_flow_id,
     // Error policy register
     input logic        error_policy_next_packet,
     // Flag Output beats that are active sample data vs zero padding
     output logic       run_out,
     // Dirt/DRat packetized stream in
     axis_t.slave axis_pkt,
     // Status pkt stream out
     axis_t.master axis_status,
     // Consumption pkt stream out
     axis_t.master axis_consumption,
     // Stream oriented raw IQ samples out
     axis_t.master axis_stream
     );

    import drat_protocol::*;
    import axis_pkt_to_stream_pkg::*;


    wire [63:0]          probe ; // Debug


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
                                   .enable_in(deframer_enable),
                                   .axis_pkt_in(axis_pkt),
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
                         .out_axis(axis_head),
                         .space(),
                         .occupied()
                         );




    axis_tx_control axis_tx_control_i (
                                       .clk(clk),
                                       .rst(rst),
                                       .enable_in(tx_control_enable),
                                       .error_policy_next_packet_in(error_policy_next_packet),
                                       .consumption_period(consumption_period),
                                       .axis_head_in(axis_head),
                                       .now_in(now),
                                       .late_in(late),
                                       .generate_pkt_out(generate_pkt),
                                       .status_payload_out(status_payload),
                                       .generate_consumption_out(generate_consumption),
                                       .consumed_seq_num_out(consumed_seq_num),
                                       .run_out(run_out),
                                       .axis_stream(axis_stream)
                                       );

    //
    // Send status reports upstream
    //
    axis_status_report axis_status_report_i (
                                             .clk(clk),
                                             .rst(rst),
                                             .enable_in(status_enable),
                                             .flow_id_in(status_flow_id),
                                             .generate_pkt_in(generate_pkt),
                                             .status_payload_in(status_payload),
                                             .current_time_in(current_time),
                                             .axis_status_out(axis_status)
                                             );

    //
    // Send packet consumption reports upstream *FINISH!*
    //
    axis_status_report axis_consumption_report_i (
                                                  .clk(clk),
                                                  .rst(rst),
                                                  .enable_in(consumption_enable),
                                                  .flow_id_in(consumption_flow_id),
                                                  .generate_pkt_in(generate_consumption),
                                                  .status_payload_in({ACK,24'h0,consumed_seq_num}),
                                                  .current_time_in(current_time),
                                                  .axis_status_out(axis_consumption)
                                                  );


    //
    // Compare actual time to on-air time
    //
    time_check time_check_i (
                             .clk(clk),
                             .rst(rst),
                             .current_time(current_time),
                             .event_time(axis_head.tdata[127:64]),
                             .early(),
                             .now(now),
                             .late(late)
                             );

   //-------------------------------------------------------------------------------
   // Debug Only below
   //-------------------------------------------------------------------------------


   //assign probe = 64'h0;
/*
   assign probe[0] =  axis_pkt.tvalid;
   assign probe[1] = axis_pkt.tready;
   assign probe[2] =  axis_pkt.tlast;
   assign probe[10:3] = axis_pkt.tdata[7:0];

   assign probe[11] = axis_status.tvalid;
   assign probe[12] = axis_status.tready;
   assign probe[13] = axis_status.tlast;
   assign probe[21:14] = axis_status.tdata[39:32];

   assign probe[22] = axis_consumption.tvalid;
   assign probe[23] = axis_consumption.tready;
   assign probe[24] = axis_consumption.tlast;
   assign probe[32:25] = axis_consumption.tdata[39:32];
   assign probe[26:11] = debug_tx_control[15:0];
   assign probe[27] = status_enable;
   assign probe[28] = consumption_enable;
   assign probe[29] = tx_control_enable;

   assign probe[30] = 0;
   assign probe[31] = axis_stream_tready2;
   assign probe[32] = axis_stream.tready;
   assign probe[33] = axis_stream.tvalid;
   assign probe[34] = axis_stream_tready;


   assign probe[50:35] = axis_stream.tdata[15:0];

   assign probe[51] = run_out;

   assign probe[63:52] = 0;

   ila_64 ila_64_i0 (
	.clk(clk), // input wire clk

	.probe0(probe[0]), // input wire [0:0]  probe0
	.probe1(probe[1]), // input wire [0:0]  probe1
	.probe2(probe[2]), // input wire [0:0]  probe2
	.probe3(probe[3]), // input wire [0:0]  probe3
	.probe4(probe[4]), // input wire [0:0]  probe4
	.probe5(probe[5]), // input wire [0:0]  probe5
	.probe6(probe[6]), // input wire [0:0]  probe6
	.probe7(probe[7]), // input wire [0:0]  probe7
	.probe8(probe[8]), // input wire [0:0]  probe8
	.probe9(probe[9]), // input wire [0:0]  probe9
	.probe10(probe[10]), // input wire [0:0]  probe10
	.probe11(probe[11]), // input wire [0:0]  probe11
	.probe12(probe[12]), // input wire [0:0]  probe12
	.probe13(probe[13]), // input wire [0:0]  probe13
	.probe14(probe[14]), // input wire [0:0]  probe14
	.probe15(probe[15]), // input wire [0:0]  probe15
	.probe16(probe[16]), // input wire [0:0]  probe16
	.probe17(probe[17]), // input wire [0:0]  probe17
	.probe18(probe[18]), // input wire [0:0]  probe18
	.probe19(probe[19]), // input wire [0:0]  probe19
	.probe20(probe[20]), // input wire [0:0]  probe20
	.probe21(probe[21]), // input wire [0:0]  probe21
	.probe22(probe[22]), // input wire [0:0]  probe22
	.probe23(probe[23]), // input wire [0:0]  probe23
	.probe24(probe[24]), // input wire [0:0]  probe24
	.probe25(probe[25]), // input wire [0:0]  probe25
	.probe26(probe[26]), // input wire [0:0]  probe26
	.probe27(probe[27]), // input wire [0:0]  probe27
	.probe28(probe[28]), // input wire [0:0]  probe28
	.probe29(probe[29]), // input wire [0:0]  probe29
	.probe30(probe[30]), // input wire [0:0]  probe30
	.probe31(probe[31]), // input wire [0:0]  probe31
	.probe32(probe[32]), // input wire [0:0]  probe32
	.probe33(probe[33]), // input wire [0:0]  probe33
	.probe34(probe[34]), // input wire [0:0]  probe34
	.probe35(probe[35]), // input wire [0:0]  probe35
	.probe36(probe[36]), // input wire [0:0]  probe36
	.probe37(probe[37]), // input wire [0:0]  probe37
	.probe38(probe[38]), // input wire [0:0]  probe38
	.probe39(probe[39]), // input wire [0:0]  probe39
	.probe40(probe[40]), // input wire [0:0]  probe40
	.probe41(probe[41]), // input wire [0:0]  probe41
	.probe42(probe[42]), // input wire [0:0]  probe42
	.probe43(probe[43]), // input wire [0:0]  probe43
	.probe44(probe[44]), // input wire [0:0]  probe44
	.probe45(probe[45]), // input wire [0:0]  probe45
	.probe46(probe[46]), // input wire [0:0]  probe46
	.probe47(probe[47]), // input wire [0:0]  probe47
	.probe48(probe[48]), // input wire [0:0]  probe48
	.probe49(probe[49]), // input wire [0:0]  probe49
	.probe50(probe[50]), // input wire [0:0]  probe50
	.probe51(probe[51]), // input wire [0:0]  probe51
	.probe52(probe[52]), // input wire [0:0]  probe52
	.probe53(probe[53]), // input wire [0:0]  probe53
	.probe54(probe[54]), // input wire [0:0]  probe54
        .probe55(probe[55]), // input wire [0:0]  probe55
	.probe56(probe[56]), // input wire [0:0]  probe56
	.probe57(probe[57]), // input wire [0:0]  probe57
	.probe58(probe[58]), // input wire [0:0]  probe58
	.probe59(probe[59]), // input wire [0:0]  probe59
	.probe60(probe[60]), // input wire [0:0]  probe60
	.probe61(probe[61]), // input wire [0:0]  probe61
	.probe62(probe[62]), // input wire [0:0]  probe62
	.probe63(probe[63]) // input wire [0:0]  probe63
);
*/
endmodule // axis_pkt_to_stream
