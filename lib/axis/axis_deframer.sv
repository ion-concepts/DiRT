//-----------------------------------------------------------------------------
// File:    axis_deframer.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// This module unframes DRaT packets, turning header fields into metadata that
// is then associated with individual sample data in the egress FIFO.
// Unsuitable packet types (non 16bit complex), or runt packets that are too short
// are rejected and filtered.
//
// When this block is not enabled it allows in progress deframing to complete but
// then remains idle in the S_HEADER state with upstream TREADY asserted, whilst it
// discards any bus beats with TVALID asserted. Note: This means there should be no
// active stream directed at this block when it is initially enabled as it would be
// possibly to sync to a non header beat in a packet in the process of being discarded.
// 
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module  axis_deframer
    (
     input logic clk,
     input logic rst,
     // Remain quiescent in S_HEADER, accepting and discarding beats if not asserted.
     input       enable_in,
     // Dirt/DRat packetized stream in
     axis_t.slave axis_pkt_in,
     // Exposed FIFO read interface
     axis_t.master axis_tail_out
     );

    import drat_protocol::*;
    import axis_pkt_to_stream_pkg::*;

    // Flag if this is an async stream (else sync)
    logic        async;
    // Flag if this packet has an odd number of smaples.
    logic        odd_length;
    // Flag if this packet indicates end of burst has been reached.
    logic        end_of_burst;
    // Sequence number extracted from header
    logic [7:0]  seq_num;
    // FLowID extracted from header
    logic [31:0] flow_id;
    // Timestamp extracted from header
    logic [63:0] timestamp;
    // FIFO output bus is packed struct data
    //pkt_to_stream_fifo_t beat;


    // States
    enum         {
                  S_HEADER,
                  S_TIME,
                  S_PAYLOAD,
                  S_PURGE
                  } state;


    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_HEADER;
            async <= 1'b0;
            flow_id <= 32'h0;
            seq_num <= 8'h0;
            timestamp <= 64'h0;
            end_of_burst <= 1'b0;
            odd_length <= 1'b0;
        end else begin
            automatic drat_protocol::pkt_header_t header =
                drat_protocol::populate_header_no_timestamp(axis_pkt_in.tdata);
            case (state)
                //
                // Sit idle in S_HEADER state waiting for a bus beat marked valid.
                // We assume that this will be the header line of a DRaT packet.
                //
                S_HEADER: begin
                    if (axis_pkt_in.tvalid && enable_in) begin
                        // If the first beat of the packet is also marked as the last
                        // it's basicly malformed but to purge it quickly we just stay in
                        // the S_HEADER state and try again.
                        if (!axis_pkt_in.tlast) begin
                            // Check the type of DRaT packet, if its INT16_COMPLEX and synchronous
                            // then we have time in the next beat. If it's INT16_COMPLEX_ASYNC
                            // then jump straight into payload deframing.
                            if (
                                (header.packet_type == INT16_COMPLEX) ||
                                (header.packet_type == INT16_COMPLEX_EOB)
                                ) begin
                                // Synchronous, get time next.
                                state <= S_TIME;
                                async <= 1'b0;
                            end else if (
                                         (header.packet_type == INT16_COMPLEX_ASYNC) ||
                                         (header.packet_type == INT16_COMPLEX_ASYNC_EOB)
                                         ) begin
                                // Still get the time field for async even though it's ignored
                                // because it's present in the packet
                                state <= S_TIME;
                                async <= 1'b1;
                            end else begin // Implicitly not an INT16_COMPLEX fammily packet
                                state <= S_PURGE;
                            end
                        end // if (!axis_pkt_in.tlast)

                        flow_id <= header.flow_id;
                        seq_num <= header.seq_id;
                        end_of_burst <= (header.packet_type == INT16_COMPLEX_EOB) ||
                                        (header.packet_type == INT16_COMPLEX_ASYNC_EOB);
                        odd_length <= axis_pkt_in.tdata[34]; // Complex samples are 32bits.
                    end // if (axis_pkt_in.tvalid)
                end // case: S_HEADER
                //
                // Extract timestamp for synchronous streams.
                //
                S_TIME: begin
                    if (axis_pkt_in.tvalid) begin
                        timestamp <= axis_pkt_in.tdata[63:0];
                        if (axis_pkt_in.tlast) begin
                            // Malformed runt packet, go back idle.
                            state <= S_HEADER;
                        end else begin
                            state <= S_PAYLOAD;
                        end
                    end
                end // case: S_TIME
                //
                // Pass through Payload beats until tlast asserted and passed through
                //
                S_PAYLOAD: begin
                    if (axis_pkt_in.tvalid && axis_pkt_in.tlast && axis_tail_out.tready) begin
                        state <= S_HEADER;
                    end
                end
                //
                // Dump upstream beats until end of packet signalled with TLAST
                //
                S_PURGE: begin
                    if (axis_pkt_in.tvalid) begin
                        if (axis_pkt_in.tlast) begin
                            state <= S_HEADER;
                        end
                    end
                end

            endcase // case (state)
        end // else: !if(rst)
    end // always_ff @ (posedge clk)

    always_comb begin
        automatic axis_pkt_to_stream_pkg::pkt_to_stream_fifo_t beat_out;
        automatic drat_protocol::payload_beat_t beat_in = populate_int16_complex_beat(axis_pkt_in.tdata);

        axis_tail_out.tvalid = axis_pkt_in.tvalid && (state == S_PAYLOAD);
        axis_pkt_in.tready = (state == S_PAYLOAD) ? axis_tail_out.tready : 1'b1;
        beat_out.odd = odd_length;
        beat_out.async = async;
        beat_out.eob = end_of_burst;
        beat_out.eop = axis_pkt_in.tlast;
        beat_out.seq_num = seq_num;
        beat_out.flow_id = flow_id;
        beat_out.timestamp = timestamp;
        beat_out.samples.i0 = beat_in.int16_complex.i0;
        beat_out.samples.q0 = beat_in.int16_complex.q0;
        beat_out.samples.i1 = beat_in.int16_complex.i1;
        beat_out.samples.q1 = beat_in.int16_complex.q1;

        axis_tail_out.tdata = beat_out;

        // TLAST Unused, FIFO stream is sample not packet oriented.
        // EOP/EOB flags in metadata fields.
        axis_tail_out.tlast = 1'b0;

    end

endmodule // axis_deframer
