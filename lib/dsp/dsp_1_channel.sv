//-----------------------------------------------------------------------------
// File:   dsp_1_channel.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Simple 1 channel TX/RX DSP.
// DRaT protocol
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module dsp_1_channel
  #(
    parameter TX_DATA_FIFO_SIZE = 12,  // Must be substantial for high TX rates and large MTU's
    parameter TX_STATUS_FIFO_SIZE = 5, // Default to SRL32 implementation
    parameter RX_TIME_FIFO_SIZE = 4,  // Default from axis_stream_to_pkt_wrapper
    parameter RX_SAMPLE_FIFO_SIZE = 13,  // Default from axis_stream_to_pkt_wrapper
    parameter RX_PACKET_FIFO_SIZE = 8,  // Default from axis_stream_to_pkt_wrapper
    parameter RX_DATA_FIFO_SIZE = 10,
    parameter IQ_WIDTH = 16  // Default from axis_stream_to_pkt_wrapper
    )
   (
    input logic        clk,
    input logic        rst,
    //
    // Control and Status Regs (CSR)
    //
    input logic        csr_tx_deframer_enable,
    input logic        csr_tx_status_enable,
    input logic        csr_tx_consumption_enable,
    input logic        csr_tx_control_enable,
    // FlowID to me used in status packet header
    input logic [31:0] csr_tx_status_flow_id,
    // FlowID to me used in consumption packet header
    input logic [31:0] csr_tx_consumption_flow_id,
    // Error policy register
    input logic        csr_tx_error_policy_next_packet,
    // Enable stream_to_pkt block
    input logic        csr_stream_to_pkt_enable,
    // Packet size expressed in number of samples
    input logic [13:0] csr_rx_packet_size,
    // DRaT Flow ID for this flow (union of src + dst)
    input logic [31:0] csr_rx_flow_id,
    // Time increment per packet of size packet_size
    input logic [15:0] csr_rx_time_per_pkt,
    // Number of samples in a burst. Write to zero for infinite burst.
    input logic [47:0] csr_rx_burst_size,
    // Assert this signal for a single cycle to trigger an async return to idle.
    input logic        csr_rx_abort,
    // Status Flags
    output logic       csr_stream_to_pkt_idle, // Assert when state machine is idle
    // System Time Output
    input logic [63:0]  system_time,
    // RX sample Input Bus
    axis_t.slave axis_rx_sample,
    // TX Sample Output Bus
    axis_t.master axis_tx_sample,
    // DRaT packets in
    axis_t.slave axis_tx_packet,
    // DRaT packets out
    axis_t.master axis_rx_packet
    );

   wire [63:0] probe ; // Debug
   wire        run;

   //-----------------------------------------------------------------------------
   //
   // Tx
   //
   //-----------------------------------------------------------------------------
   axis_t #(.WIDTH(64)) axis_tx_packet_fifo(.clk(clk));
   axis_t #(.WIDTH(64)) axis_tx_error(.clk(clk));
   axis_t #(.WIDTH(64)) axis_tx_consumption(.clk(clk));
   axis_t #(.WIDTH(64)) axis_tx_status(.clk(clk));
   axis_t #(.WIDTH(64)) axis_null_src0(.clk(clk));
   axis_t #(.WIDTH(64)) axis_null_src1(.clk(clk));
   axis_t #(.WIDTH(64)) axis_null_src2(.clk(clk));
   axis_t #(.WIDTH(64)) axis_null_src3(.clk(clk));
   axis_t #(.WIDTH(64)) axis_tx_status_mux(.clk(clk));




   //-------------------------------------------------------------------------------
   // Dedicated elastic buffering that is the dataplane element that flow control
   // trys to keep nominally full to prevent starvation/underflow and mask transport jitter.
   //-------------------------------------------------------------------------------
   logic [TX_DATA_FIFO_SIZE:0] tx_data_buffer_fullness;

   axis_fifo_wrapper  #(
                        .SIZE(TX_DATA_FIFO_SIZE)
                         )
   axis_fifo_tx_buffer_i0 (
                           .clk(clk),
                           .rst(rst),
                           .in_axis(axis_tx_packet),
                           .out_axis(axis_tx_packet_fifo),
                           .space(),
                           .occupied(tx_data_buffer_fullness)
                           );

   //-------------------------------------------------------------------------------
   // Unpack packets in sync with time to present stream on sample bus
   //-------------------------------------------------------------------------------
   axis_pkt_to_stream axis_pkt_to_stream_i0
     (
      .clk(clk),
      .rst(rst),
      // enable pins
      .deframer_enable(csr_tx_deframer_enable),
      .status_enable(csr_tx_status_enable),
      .consumption_enable(csr_tx_consumption_enable),
      .tx_control_enable(csr_tx_control_enable),
      // System time in
      .current_time(system_time),
      // FlowID to be used in status packet header
      .status_flow_id(csr_tx_status_flow_id),
      // FlowID to be used in consumption packet header
      .consumption_flow_id(csr_tx_consumption_flow_id),
      // Error policy register
      .error_policy_next_packet(csr_tx_error_policy_next_packet),
      // Flag Output beats that are active sample data vs zero padding
      .run_out(run),
      // Dirt/DRat packetized stream in
      .axis_pkt(axis_tx_packet_fifo),
      // Status pkt stream out
      .axis_status(axis_tx_error),
      // Consumption pkt stream out
      .axis_consumption(axis_tx_consumption),
      // Stream oriented raw IQ samples out
      .axis_stream(axis_tx_sample)
      );

   //-------------------------------------------------------------------------------
   // Mux and Buffer status packets generated as part of the unpacking process.
   // These flow back upstream to the flow source
   //-------------------------------------------------------------------------------
   axis_null_src axis_null_src_i0
     (
      .out_axis(axis_null_src0)
      );

   axis_null_src axis_null_src_i1
     (
      .out_axis(axis_null_src1)
      );


   axis_mux4_wrapper #(
                       .BUFFER(0),
                       .PRIORITY(0)
                       )
   axis_mux4_status_i0 (
                        .clk(clk),
                        .rst(rst),
                        .in0_axis(axis_tx_error),
                        .in1_axis(axis_tx_consumption),
                        .in2_axis(axis_null_src0),
                        .in3_axis(axis_null_src1),
                        .out_axis(axis_tx_status_mux)
                        );

   axis_fifo_wrapper  #(
                        .SIZE(TX_STATUS_FIFO_SIZE)
                        )
   axis_fifo_status_i0 (
                        .clk(clk),
                        .rst(rst),
                        .in_axis(axis_tx_status_mux),
                        .out_axis(axis_tx_status),
                        .space(),
                        .occupied()
                        );

   //-----------------------------------------------------------------------------
   //
   // Rx
   //
   // axis_stream_to_pkt_backpressured packetizes streaming samples suppied on an AXIS bus
   // using DRaT as the encapsulation.
   //
   //-------------------------------------------------------------------------------
   axis_t #(.WIDTH(64)) axis_rx_data(.clk(clk));
   axis_t #(.WIDTH(64)) axis_rx_data_fifo(.clk(clk));

   axis_stream_to_pkt_backpressured
     #(
       .TIME_FIFO_SIZE(RX_TIME_FIFO_SIZE),
       .SAMPLE_FIFO_SIZE(RX_SAMPLE_FIFO_SIZE),
       .PACKET_FIFO_SIZE(RX_PACKET_FIFO_SIZE),
       .IQ_WIDTH(IQ_WIDTH)
       )
   axis_stream_to_pkt_backpressured_i0
     (
      .clk(clk),
      .rst(rst),
      //-------------------------------------------------------------------------------
      // CSR registers
      //-------------------------------------------------------------------------------
      .enable(csr_stream_to_pkt_enable),
      .start_time(system_time),
      .packet_size(csr_rx_packet_size),
      .flow_id(csr_rx_flow_id),
      .time_per_pkt(csr_rx_time_per_pkt),
      .burst_size(csr_rx_burst_size),
      .abort(csr_rx_abort),
      // Status Flags
      .idle(csr_stream_to_pkt_idle),
      //-------------------------------------------------------------------------------
      // Streaming sample Input Bus
      //-------------------------------------------------------------------------------
      .axis_stream(axis_rx_sample),
      //-------------------------------------------------------------------------------
      // AXIS Output Bus
      //-------------------------------------------------------------------------------
      .axis_pkt(axis_rx_data)
      );

   axis_fifo_wrapper  #(
                        .SIZE(RX_DATA_FIFO_SIZE)
                        )
   axis_fifo_rx_data_i0 (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_rx_data),
                         .out_axis(axis_rx_data_fifo),
                         .space(),
                         .occupied()
                         );

   //-------------------------------------------------------------------------------
   // Mux TX status packet flow with RX data packet flow
   //-------------------------------------------------------------------------------
   axis_null_src axis_null_src_i2
     (
      .out_axis(axis_null_src2)
      );

   axis_null_src axis_null_src_i3
     (
      .out_axis(axis_null_src3)
      );


   axis_mux4_wrapper #(
                       .BUFFER(0),
                       .PRIORITY(0)
                       )
   axis_mux4_rx_packet_i1 (
                        .clk(clk),
                        .rst(rst),
                        .in0_axis(axis_tx_status),
                        .in1_axis(axis_rx_data_fifo),
                        .in2_axis(axis_null_src2),
                        .in3_axis(axis_null_src3),
                        .out_axis(axis_rx_packet)
                        );
    //-------------------------------------------------------------------------------
   // Debug Only below
   //-------------------------------------------------------------------------------
   //assign probe = 64'h0;
/*
   assign probe[0] =  axis_rx_sample.tvalid;
   assign probe[1] = axis_rx_sample.tready;
   assign probe[2] =  axis_rx_sample.tlast;
   assign probe[10:3] = axis_rx_sample.tdata[7:0];

   assign probe[11] = axis_rx_packet.tvalid;
   assign probe[12] = axis_rx_packet.tready;
   assign probe[13] = axis_rx_packet.tlast;
   assign probe[21:14] = axis_rx_packet.tdata[7:0];

   assign probe[22] = axis_rx_data.tvalid;
   assign probe[23] = axis_rx_data.tready;
   assign probe[24] = axis_rx_data.tlast;
   assign probe[32:25] = axis_rx_data.tdata[7:0];

   assign probe[33] = csr_stream_to_pkt_enable;
   assign probe[34] = csr_stream_to_pkt_idle;

   assign probe[42:35] = system_time[7:0];

   assign probe[56:43] = csr_rx_packet_size;

   assign probe[57] = csr_tx_deframer_enable;
   assign probe[58] = csr_tx_status_enable;
   assign probe[59] = csr_tx_consumption_enable;
   assign probe[60] = csr_tx_control_enable;
   assign probe[61] = run;




   assign probe[63:62] = 0;



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
endmodule
