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
    // Write this register with start time to annotate into bursts first packet.
    input logic [63:0] csr_rx_start_time,
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
      .start_time(csr_rx_start_time),
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
      .axis_stream_in(axis_rx_sample),
      //-------------------------------------------------------------------------------
      // AXIS Output Bus
      //-------------------------------------------------------------------------------
      .axis_pkt_out(axis_rx_data)
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
                        .in0_axis(axis_tx_status_mux),
                        .in1_axis(axis_rx_data_fifo),
                        .in2_axis(axis_null_src2),
                        .in3_axis(axis_null_src3),
                        .out_axis(axis_rx_packet)
                        );
   
endmodule 
