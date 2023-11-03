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
    // Interval between consumption packets
    input logic [7:0]  csr_tx_consumption_period,
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
    input logic [63:0] system_time,
    // RX sample Input Bus
    axis_t.slave axis_rx_sample,
    // TX Sample Output Bus
    axis_t.master axis_tx_sample,
    //input logic tx_strobe,
    // DRaT packets in
    axis_t.slave axis_tx_packet,
    // DRaT packets out
    axis_t.master axis_rx_packet
    );

   //-------------------------------------------------------------------------------
   // TX
   //-------------------------------------------------------------------------------
   axis_t #(.WIDTH(64)) axis_tx_status_packet(.clk(clk));
   
   dsp_tx
     #(
       .TX_DATA_FIFO_SIZE(12),  // Must be substantial for high TX rates and large MTU's
       .TX_STATUS_FIFO_SIZE(5), // Default to SRL32 implementation
       .IQ_WIDTH(16)  // Default from axis_stream_to_pkt_wrapper
       )
   dsp_tx_i0
     (
      .clk(clk),
      .rst(rst),
      //
      // Control and Status Regs (CSR)
      //
      .csr_tx_deframer_enable(csr_tx_deframer_enable),
      .csr_tx_status_enable(csr_tx_status_enable),
      .csr_tx_consumption_enable(csr_tx_consumption_enable),
      .csr_tx_control_enable(csr_tx_control_enable),
      // FlowID to me used in status packet header
      .csr_tx_status_flow_id(csr_tx_status_flow_id),
      // FlowID to me used in consumption packet header
      .csr_tx_consumption_flow_id(csr_tx_consumption_flow_id),
      // Error policy register
      .csr_tx_error_policy_next_packet(csr_tx_error_policy_next_packet),
      // System Time Input
      .system_time(system_time),
      // TX Sample Output Bus
      .axis_tx_sample(axis_tx_sample),
      // DRaT packets in
      .axis_tx_packet(axis_tx_packet),
      // DRaT packets out
      .axis_tx_status_packet(axis_tx_status_packet)
      );

   //-------------------------------------------------------------------------------
   // RX
   //-------------------------------------------------------------------------------
   axis_t #(.WIDTH(64)) axis_rx_packet_pre_mux(.clk(clk));
    
   dsp_rx
     #(
       .RX_TIME_FIFO_SIZE(4),  // Default from axis_stream_to_pkt_wrapper
       .RX_SAMPLE_FIFO_SIZE(13),  // Default from axis_stream_to_pkt_wrapper
       .RX_PACKET_FIFO_SIZE(8),  // Default from axis_stream_to_pkt_wrapper
       .RX_DATA_FIFO_SIZE(10),
       .IQ_WIDTH(16)  // Default from axis_stream_to_pkt_wrapper
       )
   dsp_rx_i0
     (
      .clk(clk),
      .rst(rst),
      //
      // Control and Status Regs (CSR)
      //
      // Enable stream_to_pkt block
      .csr_stream_to_pkt_enable(csr_stream_to_pkt_enable),
      // Packet size expressed in number of samples
      .csr_rx_packet_size(csr_rx_packet_size),
      // DRaT Flow ID for this flow (union of src + dst)
      .csr_rx_flow_id(csr_rx_flow_id),
      // Time increment per packet of size packet_size
      .csr_rx_time_per_pkt(csr_rx_time_per_pkt),
      // Number of samples in a burst. Write to zero for infinite burst.
      .csr_rx_burst_size(csr_rx_burst_size),
      // Assert this signal for a single cycle to trigger an async return to idle.
      .csr_rx_abort(csr_rx_abort),
      // Status Flags
      .csr_stream_to_pkt_idle(csr_stream_to_pkt_idle), // Assert when state machine is idle
      // System Time Input
      .system_time(system_time),
      // RX sample Input Bus
      .axis_rx_sample(axis_rx_sample),
      // DRaT packets out
      .axis_rx_packet(axis_rx_packet_pre_mux)
      );

   //-------------------------------------------------------------------------------
   // Mux TX status packet flow with RX data packet flow
   //-------------------------------------------------------------------------------
   axis_t #(.WIDTH(64)) axis_null_src0(.clk(clk));
   axis_t #(.WIDTH(64)) axis_null_src1(.clk(clk));

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
   axis_mux4_rx_packet_i1 (
                        .clk(clk),
                        .rst(rst),
                        .in0_axis(axis_tx_status_packet),
                        .in1_axis(axis_rx_packet_pre_mux),
                        .in2_axis(axis_null_src0),
                        .in3_axis(axis_null_src1),
                        .out_axis(axis_rx_packet)
                        );

endmodule
