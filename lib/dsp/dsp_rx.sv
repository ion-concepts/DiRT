
//-----------------------------------------------------------------------------
// File:   dsp_rx.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Simple 1 channel RX DSP.
// DRaT protocol
// Packetizes RX sample stream into DRaT transport with timestamping
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

module dsp_rx
  #(
    parameter RX_TIME_FIFO_SIZE = 4,  // Default from axis_stream_to_pkt_wrapper
    parameter RX_SAMPLE_FIFO_SIZE = 12,  // Default from axis_stream_to_pkt_wrapper
    parameter RX_PACKET_FIFO_SIZE = 9,  // Default from axis_stream_to_pkt_wrapper
    parameter IQ_WIDTH = 16  // Default from axis_stream_to_pkt_wrapper
    )
   (
    input logic        clk,
    input logic        rst,
    //
    // Control and Status Regs (CSR)
    //
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
    // DRaT packets out
    axis_t.master axis_rx_packet
    );

   wire [63:0] probe ; // Debug
   wire        run;

   //-----------------------------------------------------------------------------
   //
   // Rx
   //
   // axis_stream_to_pkt_backpressured packetizes streaming samples suppied on an AXIS bus
   // using DRaT as the encapsulation.
   //
   //-------------------------------------------------------------------------------
   axis_t #(.WIDTH(64)) axis_rx_packet_pre_fifo(.clk(clk));
  
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
      .axis_pkt(axis_rx_packet_pre_fifo)
      );

   // Breaks all combinatorial timing paths, helps with timing closure.
   axis_minimal_fifo_wrapper framer_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_rx_packet_pre_fifo),
      .out_axis(axis_rx_packet),
      .space_out(,
      .occupied_out()
      );


    //-------------------------------------------------------------------------------
   // Debug Only below
   //-------------------------------------------------------------------------------
   //assign probe = 64'h0;
/*

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
