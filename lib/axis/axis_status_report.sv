//-----------------------------------------------------------------------------
// File:    axis_status_report.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// This module emits async STATUS packets on demand.
// It accepts a pre-formatted payload field but maintains
// it's own Sequence Number counter. FlowID is applied externally but should
// not be changed during operation, only when dissabled.
//
// An input signal "generate_pkt_in" triggers packet generation.
// This signal is not handshaked and once it has been asserted
// across a clock edge the asserter is resposible for de-asserting
// it within 4 clock cycles or another status packet may be generated.
//
// Because the signal is not handshaked the asserter has no guarantee
// that a status packet has been generated. Excessive congestion that
// might back pressure the egress AXIS interface will cause the packet
// generation state machine to take longer to cycle back to the S_IDLE state
// which is the only state that reads "generate_pkt_in".
//
// Additionally "status_payload_in", will be read as a result of the detected assertion
// of generate_pkt_in, but only a minimum of 3 clock cycles later, as the state machine
// constructs the status pkt payload field. The larger system must be designed around
// this constraint, or a status packet may be lost (This may be the explicit strategy!)
//
// A future design direction is to switch status_payload to being passed via a FIFO
// from axis_tx_control if performance problems occur with this interface in a system.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_status_report
    (
     input logic        clk,
     input logic        rst,
     // Remain quiescent in S_IDLE if not asserted.
     input logic        enable_in,
     // Assert to trigger Status packet generation
     input logic        generate_pkt_in,
     // FlowID to be used in status packet header
     input logic [31:0] flow_id_in,
     // Preformatted Payload field
     input logic [63:0] status_payload_in,
     // Current System Time
     input logic [63:0] current_time_in,
     // Dirt/DRat packetized stream out
     axis_t.master axis_status_out

     );
    import drat_protocol::*;

    // Length in bytes of a DRaT status packet
    localparam logic [15:0] C_STATUS_PACKET_LENGTH = 16'd24;
    // DRaT packet type encoding
    localparam pkt_type_t C_PKT_TYPE = STATUS;

    // States
    enum                    {
                             S_IDLE,
                             S_HEADER,
                             S_TIME,
                             S_PAYLOAD
                             } state;

    // Hardcoded to always generate a STATUS packet


    logic [7:0]             seq_num;

    // When not enabled, Seq Num will be reset.
    always_ff @(posedge clk)
        if(rst) begin
            seq_num <= 12'd0;
        end else if ((state == S_IDLE) && ~enable_in) begin
            // Disabling block will reset Seq Num as it goes idle.
            seq_num <= 12'd0;
        end else if ((state == S_PAYLOAD) && axis_status_out.tready) begin
            seq_num <= seq_num + 12'd1;
        end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
        end else begin
            case (state)
                // Spin in this state until the generation of a packet is triggered.
                S_IDLE: begin
                    if (generate_pkt_in && enable_in)
                        state <= S_HEADER;
                end
                // Generate DRaT STATUS Header beat
                S_HEADER: begin
                    if (axis_status_out.tready)
                        state <= S_TIME;
                end
                // Generate DRaT STATUS Timestamp beat
                S_TIME: begin
                    if (axis_status_out.tready)
                        state <= S_PAYLOAD;
                end
                // Generate DRaT STATUS Payload beat
                S_PAYLOAD: begin
                    if (axis_status_out.tready)
                        state <= S_IDLE;
                end
            endcase // case (state)
        end // else: !if(rst)
    end

    // Mux different DRaT beats onto the bus.
    // (Note many of these paths pass through combinatorially.)
    always_comb beginout
        axis_status_out.tvalid = (state != S_IDLE);
        axis_status_out.tlast = (state == S_PAYLOAD);
        case(state)
            S_HEADER  : axis_status_out.tdata = { C_PKT_TYPE, seq_num, C_STATUS_PACKET_LENGTH, flow_id_in };
            S_TIME    : axis_status_out.tdata = current_time_in;
            S_PAYLOAD : axis_status_out.tdata = status_payload_in;
            default : axis_status_out.tdata = 64'd0; // Arbitrary default.
        endcase // case (state)
    end

endmodule // context_packet_gen
