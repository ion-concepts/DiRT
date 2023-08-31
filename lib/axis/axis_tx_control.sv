//-----------------------------------------------------------------------------
// File:    axis_tx_control.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
//
// Description:
// This module comprises a state machine that interfaces to a downstream sample
// oriented datapath, supplying samples with zero latency whenever TREADY is asserted.
// On the upstream it interfaces with a FIFO that contains pairs of samples that are each
// decorated with metadata containing timestamp and seqnum from original packet,
// and flags identifing async/sync, EOP, EOB, and a word with only one valid sample (last
// sample in an odd length packet).
//
// The module provides logic to try to recover from forseeable error conditions
// in the most expediant and least disruptive way(s), and outputs a preformatted
// payload field for an externally generated STATUS packet that reports errors and status
// upstream (or to other destinations).
//
// Since the upstream FIFO is 2 samples wide this module can purge error causing
// packets at 2 samples a clock before attempting to recover from an error state using
// the next packet.
//
// Note that timestamps are used for initial synchronization (sync only), but once synchronized
// the seq num is used to check stream integrity which is both simpler math and allows the
// same logic to work for async and sync streams.
//
// There are 3 basic likely forms of error in a system:
// LATE - Where a packet arrives a this module with a timestamp that is already in the past
// UNDERFLOW - Where the upstream fails to make samples available in the FIFO to
//             match downstream demand.
// SEQ_ERROR - Where a packet has an unexpected out of order sequence number,
//             which is likely due to the loss of a packet on a link subject with non-zero BER
//             and integrity checking.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_tx_control
    (
     input logic         clk,
     input logic         rst,
     // Remain quiescent in S_ERROR if not asserted.
     input logic         enable_in,
     // CSR (Control/Status Register) interface
     input logic         error_policy_next_packet_in,
     input logic [7:0]   consumption_period,
                         // Interface to unframed sample FIFO
     axis_t.slave axis_head_in,
     // Time Flags
     input logic         now_in,
     input logic         late_in,
     // Preformated payload beat for STATUS packet
     output logic        generate_pkt_out,
     output logic [63:0] status_payload_out,
     // Consumption reporting interface
     output logic        generate_consumption_out,
     output logic [7:0]  consumed_seq_num_out,
     // Drive strobed sample pipeline
     output logic        run_out,
     axis_t.master axis_stream
     );

    import drat_protocol::*;
    import axis_pkt_to_stream_pkg::*;


    // Size of STATUS packet payload (One DRaT payload beat)
    localparam C_STATUS_WIDTH=64;

    // States

   localparam  S_IDLE=0;
   localparam  S_ODD=1;
   localparam  S_EVEN=2;
   localparam  S_ERROR=3;
   logic [1:0] state;


    // Various status packet payloads.
    wire [C_STATUS_WIDTH-1:0] status_eob_ack;
    wire [C_STATUS_WIDTH-1:0] status_underflow;
    wire [C_STATUS_WIDTH-1:0] status_seq_error_start;
    wire [C_STATUS_WIDTH-1:0] status_seq_error_mid;
    wire [C_STATUS_WIDTH-1:0] status_late;

    // Extract state and metadata from FIFO.
    wire                      bad_seq_num;
    wire                      seq_num_plus_one;

    // FIFO output bus is packed struct data
    pkt_to_stream_fifo_t beat;

    always_comb begin
        beat = axis_head_in.tdata;
    end

    //
    // Reset Sequence Number in a number of situations:
    //
    wire                      rst_seq_num;

    assign rst_seq_num =(
                         // In Error state and error_policy is BURST
                         ((state == S_ERROR) && ~error_policy_next_packet_in) ||
                         //  In Error state because we are dissabled and discarding beats.
                         ((state == S_ERROR) && ~enable_in) ||
                         // Burst just ended on this sample regardless of state
                         // (sample_tready deals with both the odd and even length cases)
                         (axis_head_in.tvalid && axis_head_in.tready && beat.eop && beat.eob)
                         );

    wire                      inc_seq_num;

    // Increment expected sequence number the same cycle we pop a FIFO entry that has EOP set or
    // when we get a mid-burst sequence number off-by-one error. We ignore configured error policy here
    // to simplify this logic, though in "next burst" we ultimately want to reset the seq_num, not inc it.
    assign inc_seq_num = (beat.eop && axis_head_in.tvalid && axis_head_in.tready) ||
                         (state == S_ODD && axis_stream.tready && axis_head_in.tvalid && seq_num_plus_one);


    //
    // Maintain reference count of Sequence Numbers.
    //
    logic [7:0]               expected_seq_num;

    always_ff @(posedge clk) begin
        if (rst) begin
            expected_seq_num <= 8'h0;
        end else if (rst_seq_num) begin
            // Sequence number can be reset due to start of new burst (Either normal or through error)
            expected_seq_num <= 8'h0;
        end else if (inc_seq_num) begin
            // This is a Modulo256 counter, it's designed to roll over.
            expected_seq_num <= expected_seq_num + 1'b1;
        end
    end // always_ff @ (posedge clk)

    assign bad_seq_num = expected_seq_num != beat.seq_num;
    assign seq_num_plus_one  = ( beat.seq_num == (expected_seq_num + 1'b1));

    //
    // Maintain counter that sets period of consumption packet generation
    //
   logic [7:0] consumption_counter;
   logic       consumption_inc;


    always_ff @(posedge clk) begin
       if (rst) begin
          generate_consumption_out <= 1'b1;
          consumed_seq_num_out <= 0;
          consumption_counter <= 1;
       end else if (consumption_period == 0) begin
          // Do nothing. No consumption packets generated. Also allows S/W reset of count.
          consumption_counter <= 1;
          generate_consumption_out <= 1'b0;
       end else if (consumption_inc && (consumption_counter == consumption_period)) begin
          // Issue consumption packet, reset count.
          //
          // Assert generate_consumption_out at instant of consumption
          // but latch seq_num persistantly so we don't have to act on it this cycle.
          // If we are so tardy externally that another packet gets consumed in the mean time
          // then the seq_num is harmlessly updated to effectively update the original consumption report.
          //
          generate_consumption_out <= 1'b1;
          consumed_seq_num_out <= beat.seq_num;
          consumption_counter <= 1;
       end else if (consumption_inc) begin
          consumption_counter <= consumption_counter + 1;
          generate_consumption_out <= 1'b0;
       end else begin
          // Default
          generate_consumption_out <= 1'b0;
       end
    end // always_ff @ (posedge clk)



    //
    // State Machine
    //
    always_ff @(posedge clk) begin
        if (rst) begin
            generate_pkt_out <= 1'b0;
            status_payload_out <= 64'h0;
            axis_stream.tvalid <= 1'b0;
            consumption_inc <= 1'b0;
            state <= S_IDLE;
        end else if (~enable_in) begin
            // Transition to S_ERROR immediatly if not enabled and discard input data
            // whilst driving zero valued samples out of egress.
            state <= S_ERROR;
            axis_stream.tvalid <= 1'b1;
            generate_pkt_out <= 1'b0;
            status_payload_out <= 64'h0;
            consumption_inc <= 1'b0;
        end else begin
            // Defaults
            axis_stream.tvalid <= 1'b1;
            generate_pkt_out <= 1'b0;
            consumption_inc <= 1'b0;
            // End defaults.
            case (state)
                //
                // In the S_IDLE state we wait for the start of new bursts or packets.
                // There is no explicit SOB/SOP marker, the first cycle with asserted TVALID
                // is implicitly treated as such. We only search for the start of a new packet
                // (but not burst) here when trying to re-sync after an error.
                //
                S_IDLE: begin
                    if (axis_head_in.tvalid) begin
                        if (beat.async || now_in) begin
                            // Either an async stream or dispatch time for sync stream
                            if (bad_seq_num) begin
                                // This was not the starting Sequence number we expected
                                state <= S_ERROR;
                                generate_pkt_out <= 1'b1;
                                status_payload_out <= status_seq_error_start;
                            end else begin
                                // Start of Burst
                                state <= S_ODD;
                            end
                        end else if (late_in) begin
                            // Start of synchronous burst has arrived here late.
                            state <= S_ERROR;
                            generate_pkt_out <= 1'b1;
                            status_payload_out <= status_late;
                        end
                    end // if (axis_head_in.tvalid)
                end // case: S_IDLE
                //
                // In the S_ODD state we process the first (left most) complex sample
                // in the input TDATA bus.
                //
                S_ODD: begin
                    if (axis_stream.tready) begin
                        // Downstream wants a sample this cycle.
                        if (!axis_head_in.tvalid) begin
                            // ....but no sample available...RUH ROH underflow!
                            state <= S_ERROR;
                            generate_pkt_out <= 1'b1;
                            status_payload_out <= status_underflow;
                        end else if (seq_num_plus_one && error_policy_next_packet_in) begin
                            // This was not the sequence number we expected,
                            // however it looks like the next packet we expected so likely
                            // we just lost a single packet in transport.
                            // Rather than purge this packet we go direct back to S_IDLE
                            // and leave this packet in the FIFO, increment the expect seq num
                            // and allow resync to happen at the correct time.
                            // Note that even though we check this every odd sample,
                            // in practice it will only fire on the first sample of a new packet
                            // becuase all subsequent samples will have the same seq num.
                            state <= S_IDLE;
                            generate_pkt_out <= 1'b1;
                            status_payload_out <= status_seq_error_mid;
                        end else if (bad_seq_num) begin
                            // This was not the sequence number we expected.
                            // Note that even though we check this every odd sample,
                            // in practice it will fire on the first sample of a new packet
                            // becuase all subsequent samples will have the same seq num.
                            state <= S_ERROR;
                            generate_pkt_out <= 1'b1;
                            status_payload_out <= status_seq_error_mid;
                        end else if (beat.eop && beat.eob && beat.odd) begin
                            // Burst is ending on an odd length packet this cycle.
                            // TODO: Can add error policy control here later to mask this status report if desired.
                            state <= S_IDLE;
                            generate_pkt_out <= 1'b1;
                            status_payload_out <= status_eob_ack;
                            // Increment consumption counter
                            consumption_inc <= 1'b1;
                        end else if (beat.eop && beat.odd) begin
                            // Odd length Packet is ending this cycle, remain in ODD sample state
                            state <= S_ODD;
                            // Increment consumption counter
                            consumption_inc <= 1'b1;
                        end else begin
                            // Nothing special, move on to the even sample
                            state <= S_EVEN;

                        end // else: !if(bad_seq_num)
                    end // if (axis_stream.tready)
                end // case: S_ODD
                //
                // In the S_EVEN state we process the second (right most) complex sample
                // in the input TDATA bus. Note that no errors can occur in this state,
                // all possible errors having already been checked for during processing
                // of the paired odd sample.
                //
                S_EVEN: begin
                    if (axis_stream.tready) begin
                        // Downstream wants a sample this cycle.
                        if (beat.eop && beat.eob) begin
                            // Burst is ending on an even length packet this cycle.
                            // TODO: Can add error policy control here later to mask this status report if desired.
                            state <= S_IDLE;
                            generate_pkt_out <= 1'b1;
                            status_payload_out <= status_eob_ack;
                            // Increment consumption counter
                            consumption_inc <= 1'b1;
                        end else begin
                            // Nothing special, move on to odd sample (FIFO will pop now)
                            state <= S_ODD;
                            if (beat.eop) begin
                                // Increment consumption counter
                                consumption_inc <= 1'b1;
                            end
                        end
                    end // if (axis_stream.tready)
                end // case: S_EVEN
                //
                // Transition to this state on Error when desirable to purge current packet
                // in FIFO before attempting a resync by transitioning to S_IDLE
                //
                S_ERROR: begin
                    // Clear "Send Status flag"
                    generate_pkt_out <= 1'b0;
                    if (axis_head_in.tvalid && beat.eop) begin
                        // We just drained whats left of the error causing packet out of FIFO.
                        //
                        // Increment consumption counter
                        consumption_inc <= 1'b1;
                        // Time to make error policy decisions.
                        if (beat.eob || error_policy_next_packet_in) begin
                            // Policy dictates if we try to restart on a packet or burst boundry.
                            // In all cases we transition through S_IDLE and treat this as a new burst.
                            state <= S_IDLE;
                        end
                    end
                end // case: S_ERROR
                //
            endcase // case (state)
        end // else: !if(rst)
    end // always_ff @ (posedge clk)

    assign status_eob_ack = {EOB_ACK,24'h0,beat.seq_num};
    assign status_underflow = {UNDERFLOW,24'h0,beat.seq_num};
    assign status_seq_error_start = {SEQ_ERROR_START,16'h0,expected_seq_num, beat.seq_num};
    assign status_seq_error_mid = {SEQ_ERROR_MID,16'h0,expected_seq_num, beat.seq_num};
    assign status_late = {LATE,24'h0,beat.seq_num};

    //
    // Provide ready signal to the upstream FIFO
    //
    always_comb begin
        axis_head_in.tready =
                             // In error state purge a FIFO line every cycle until
                             // end of packet/burst boundry reached.
                             (state == S_ERROR) ||
                             // Downstream consumes even (2nd) sample from FIFO line
                             ((state == S_EVEN) && axis_stream.tready) ||
                             // Downstream consumes odd (1st) sample from FIFO line..
                             // but its the last sample in an odd length packet
                             // and so we pop this FIFO entry now since there is
                             // no even sample present to read.
                             ((state == S_ODD) && axis_stream.tready && beat.odd && beat.eop);
    end
    //
    // Route samples into downstream datapath
    //
    always_comb begin
        // Any error or idle state causes zero valued IQ data to be passed downstream
        // including transitions to error states from S_ODD.
        axis_stream.tdata = ((state == S_ODD) && axis_head_in.tvalid && ~bad_seq_num) ?
                                {beat.samples.i0,beat.samples.q0} :
                                (state == S_EVEN) ?
                                {beat.samples.i1,beat.samples.q1} :
                                32'h0000_0000;
        run_out = ((state == S_ODD) && axis_head_in.tvalid && ~bad_seq_num) ? 1'b1 :
                  (state == S_EVEN) ? 1'b1 : 1'b0;
        // TODO: need to discuss downstream interface, how/where we zero fill etc
        // This currently assumes a pipeline that requires a sample immediately every time TREADY is asserted.
        axis_stream.tlast = 1'b0;

    end // always_comb

   //-------------------------------------------------------------------------------
   // Debug Only below
   //-------------------------------------------------------------------------------
   wire [63:0]          probe ; // Debug

   //assign probe = 64'h0;
/*
   assign probe[17:0] = {
                         state,//[17:16]
                         enable_in,
                         beat.async,//14
                         now_in,
                         late_in,//12
                         bad_seq_num,
                         axis_head_in.tvalid, //10
                         axis_head_in.tready,
                         seq_num_plus_one,//8
                         error_policy_next_packet_in,
                         generate_consumption_out, //6
                         consumption_inc,
                         generate_pkt_out ,//4
                         beat.eob,
                         beat.odd, //2
                         beat.eop,
                         axis_stream.tready//0
                         };

   assign probe[63:18]  = 0;

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
endmodule // axis_tx_control
