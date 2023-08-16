//----------------------------------------------------------------------------
// File:    axis_stream_to_pkt_backpressured.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Parameterizable:
// * Depth of Timestamp FIFO
// * Depth of Sample FIFO
// * Depth of Packet FIFO (output)
// * Width if I/Q samples
//
// Description:
// Take IQ samples from a streaming datapath and packetize them using DRaT.
// Hard code to 16bit IQ format packets for now.
// Add timestamp to each packet for first sample. Time stamp comes from external free running counter.
//
// Samples arrive at the streaming input with every valid qualified clock edge.
// If packetization is not enabled they are then dropped on the floor, but never buffered.
// Once packetization is enabled, the next clock edge with a valid sample triggers both:
// 1) (Lossless) Buffering of this and subsequent samples (until packetization is again dissabled)
// 2) Snapshot of timestamp into frozen_time. (Timestamp is time value for first sample in
// the packet we are now framing).
// Each time packet payload size threshold reached grab new snapshot of timestamp.
//
// Output State Machine:
// Wait for valid time on FIFO output (and occupancy of sample FIFO to exceed packet_size?)
// Push 1st header line onto output FIFO including: type/size/flowID/SeqID
// Push 2nd header line onto output FIFO including: timestamp
// Push samples onto output FIFO whilst counting packet_size.
// When packet_size is reached, set tlast into output FIFO with last samples.
// Go back to starting state.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

module axis_stream_to_pkt_backpressured
  #(
    // Time FIFO has 2**TIME_FIFO_SIZE entries
    parameter TIME_FIFO_SIZE=4,
    // Sample FIFO has 2**SAMPLE_FIFO_SIZE entries
    parameter SAMPLE_FIFO_SIZE=13,
    // Packet FIFO has 2**PACKET_FIFO_SIZE entries
    parameter PACKET_FIFO_SIZE=8,
    // Width of IQ samples from Datapath. If <16b then samples MSB justified into packets.
    parameter IQ_WIDTH=16 
    )

   (
    input logic        clk,
    input logic        rst,
    // Control signals
    input logic        enable,
    input logic [63:0] start_time, // Write this register with start time to annotate into bursts first packet.
    input logic [13:0] packet_size, // Packet size expressed in number of samples
    input logic [31:0] flow_id, // DRaT Flow ID for this flow (union of src + dst)
    input logic [15:0] time_per_pkt, // Time increment per packet of size packet_size
    input logic [47:0] burst_size, // Number of samples in a burst. Write to zero for infinite burst.
    input logic        abort, // Assert this signal for a single cycle to trigger an async return to idle.
    // Status Flags
    output logic       idle, // Assert when state machine is idle
    //
    // Streaming IQ Sample bus.
    // 16bit complex samples, AXIS protocol.
    axis_t.slave axis_stream_in,
    // DiRT/DRat packetized stream out
    axis_t.master axis_pkt_out
    );

   import drat_protocol::*;

   // Hardcode all packets as synchronous DRaT 16bit IQ type for now.
   // but the hooks are here to extend this to other packet types.
   pkt_type_t   packet_type, packet_type_eob;
   assign packet_type = INT16_COMPLEX;
   assign packet_type_eob = INT16_COMPLEX_EOB;

   // Widely used boolean expressions
   logic               end_of_packet;
   logic [13:0]        input_count; // Counting in 32bit INT16_COMPLEX
   
   always_comb begin
      end_of_packet = (input_count >= packet_size);
   end

   logic end_of_burst;
   logic [47:0] burst_count;

   // EOB asserted as the remaining samples in the burst falls below
   // the traget size for packets, meaning this will be the last one.
   // NOTE: We override this logic for an "inifinite burst" which is
   // programmed as a burst_size of 0.
   always_comb begin
      end_of_burst = (burst_count <= packet_size) && (burst_size != 0);
   end

   logic               ingress_beat;
   always_comb begin
      ingress_beat = axis_stream_in.tvalid && axis_stream_in.tready;
   end

   // Signal TREADY to upstream when both time_fifo and sample_fifo have space
   // and we are enabled
   wire                     sfifo_not_full;
   wire                     tfifo_not_full;
   always_comb begin
      axis_stream_in.tready = sfifo_not_full && tfifo_not_full && enable;
   end

   //-----------------------------------------------------------------------------
   //
   // Input State machine (Mealy Machine).
   // Sizes of packet from 1 sample and up are supported.
   //
   //-----------------------------------------------------------------------------

   enum {
         S_NEW_BURST,
         S_IN_BURST 
         } burst_state;

   always_ff @(posedge clk)
     if (rst) begin
        burst_state <= S_NEW_BURST;
        burst_count <= burst_size;
     end else begin
        case(burst_state)
          //
          S_NEW_BURST: begin
             if (!enable) begin
                burst_state <= S_NEW_BURST;
                burst_count <= burst_size;
             end else  if (ingress_beat) begin
                // First beat of first packet of new burst
                if (burst_size != 0) begin
                   // Allow for infinite burst.
                   burst_count <= burst_count - 1;
                end
                if (burst_count == 1) begin
                   // EOB - Corner case 1 beat burst
                   burst_state <= S_NEW_BURST;
                   burst_count <= burst_size;
                   // TODO: GO IDLE HERE IF NOT CHAINED.
                end else begin
                   // Move to active Burst state
                   burst_state <= S_IN_BURST;
                end
             end // if (ingress_beat)
          end // case: S_NEW_BURST
          //
          S_IN_BURST: begin
             if (burst_size != 0) begin
                // Allow for infinite burst.
                burst_count <= burst_count - 1;
             end
             if (burst_count == 1) begin
                // EOB
                burst_state <= S_NEW_BURST;
                burst_count <= burst_size;
                // TODO: GO IDLE HERE IF NOT CHAINED.
             end else begin
                // Stay in active Burst state
                burst_state <= S_IN_BURST;
             end
          end // case: S_IN_BURST
        endcase // case (burst_state)
     end // else: !if(rst)


   enum {
         S_INPUT_IDLE,
         S_INPUT_PHASE1,
         S_INPUT_PHASE2
         } input_state;

   always_ff @(posedge clk)
     if (rst) begin
        input_state <= S_INPUT_IDLE;
        input_count <= 1;
     end else begin
        case(input_state)
          //
          S_INPUT_IDLE: begin
             input_count <= 1; // Samples are 32bits. Preload with 1 to account for 1 sample in flight.
             if (!enable) begin
                input_state <= S_INPUT_IDLE;
             end else if (ingress_beat) begin
                input_count <= input_count + 1'b1;
                if (input_count >= packet_size) begin
                   // Corner case - 1 sample packet config
                   input_state <= S_INPUT_IDLE;
                end else begin
                   // 1st sample of a packet gets written to holding reg as we transition from this state.
                   input_state <= S_INPUT_PHASE2;
                end
             end else begin
                input_state <= S_INPUT_IDLE;
             end
          end
          //
          // Wait for sync'ed sample to transfer to holding.
          //
          S_INPUT_PHASE1: begin
             if (ingress_beat) begin
                if (end_of_packet) begin
                   // Odd number of samples in a packet
                   input_state <= S_INPUT_IDLE;
                   input_count <= 1;
                end else begin
                   input_state <= S_INPUT_PHASE2;
                   input_count <= input_count + 1'b1;
                end
             end else begin
                input_state <= S_INPUT_PHASE1;
             end
          end
          //
          // Wait for sync'ed sample to send to FIFO with holding contents.
          // If count reached then go idle.
          //
          S_INPUT_PHASE2: begin
             if (ingress_beat) begin
                if (end_of_packet) begin
                   input_state <= S_INPUT_IDLE;
                   input_count <= 1;
                end else begin
                   input_state <= S_INPUT_PHASE1;
                   input_count <= input_count + 1'b1;
                end
             end else begin
                input_state <= S_INPUT_PHASE2;
             end
          end // case: S_INPUT_PHASE2
        endcase // case (input_state)
     end // else: !if(rst)


   //-----------------------------------------------------------------------------
   //
   // Buffer snapshots of current_time. Load externally supplied "start_time" at
   // first beat of first packet of new burst, then first beat of every subsequent packet
   // add the "time_per_packet" increment, which through careful manipulation of "packet_size"
   // caters for nominal sample rates that are not simple integer decimations of the clock speed.
   // The packet_time is inserted into the time_fifo as the last sample of a "to-yet-be-framed" packet
   // is placed into the sample_fifo.
   // This ensures that we have all the packet body already buffered in a high speed FIFO ready
   // to burst at wire rate downstream.
   //
   //-----------------------------------------------------------------------------
   logic [63:0]           packet_time;

   always_ff @(posedge clk)
     if (rst) begin
        packet_time <= 64'h0;
     end else if ((input_state==S_INPUT_IDLE) && (burst_state == S_NEW_BURST) && ingress_beat) begin
        // Start of first packet in a new burst.
        packet_time <= start_time;
     end else if ((input_state==S_INPUT_IDLE) && ingress_beat) begin
        // Start of new packet within burst, add per packet time increment.
        // Note that the only time packets are not of length "packet_size"
        // is for an EOB packet or an Async abort (i.e) the last packet
        // So we never have to calculate a custom sized packet time increment.
        packet_time <= packet_time + time_per_pkt;
     end

   // Packet size calculation in 32b samples.
   logic [13:0]           input_count_plus_header;
   always_comb begin
      input_count_plus_header = input_count+14'd4;
   end
   
   // 64bits for time, 14 bits for size in 32b words, 1bit for EOB flag
   wire [(64+14+1-1):0]   tfifo_tdata;
   wire                   tfifo_tvalid;
   logic                  tfifo_tready;
   
   axis_fifo
     #(
       .WIDTH(64+14+1),
       .SIZE(TIME_FIFO_SIZE) // Minimal, just need space for header metadata, 1 FIFO line per buffered packet.
       )
   time_fifo
     (
      .clk(clk),
      .rst(rst),
      // Input AXIS bus
      // (Control plane needs to constrain valid range of input count so it
      // can't overflow here, though in practice real systems will uses packet sizes
      // many orders of magnitude smaller than this limit)
      .in_tdata({end_of_burst,input_count_plus_header,packet_time}),
      // If upstream can advance by one beat and we have reach the threshold size for a packet
      // TODO: Will need hooks here for burst end or abort
      .in_tvalid(end_of_packet && ingress_beat && enable),
      .in_tready(tfifo_not_full),

      // Output AXIS bus
      .out_tdata(tfifo_tdata),
      .out_tvalid(tfifo_tvalid),
      .out_tready(tfifo_tready),

      // Unused
      .space(),
      .occupied()
      );

   //-----------------------------------------------------------------------------
   //
   // Buffer raw samples before forming packets out of them, so we have a pool of data to draw
   // from at wirespeed as a packet egresses.
   //
   //-----------------------------------------------------------------------------
   logic [(2*IQ_WIDTH)-1:0] sample_holding_reg;
   wire [(4*IQ_WIDTH)-1:0]  sfifo_tdata;
   wire                     sfifo_tvalid;
   logic                    sfifo_tready;
   wire                     sfifo_tlast;

   wire [(4*IQ_WIDTH)-1:0]  sfifo_minimal_tdata;
   wire                     sfifo_minimal_tvalid;
   wire                     sfifo_minimal_tready;
   wire                     sfifo_minimal_tlast;
   //
   // Always grab input data when its valid. This way the last ingress beat will be
   // available to be written in conjunction with the current ingress beat to the sample_fifo.
   //
   always_ff @(posedge clk) begin
      if (rst)
        sample_holding_reg <= 0;
      else if (ingress_beat) begin
         sample_holding_reg <= axis_stream_in.tdata;
      end
   end

   // We insert the boolean result of the packet_size threshold test as the TLAST bit
   // to mark the last beat of each packet we will form.
   // TODO: Will have to revisit this to add EOB and abort functionality to form TLAST also.

   // Unused
   wire [SAMPLE_FIFO_SIZE:0] space_sample, occupied_sample;

   axis_fifo
     #(.WIDTH((IQ_WIDTH*4)+1),
       .SIZE(SAMPLE_FIFO_SIZE))
   sample_fifo
     (
      .clk(clk),
      .rst(rst),
      // Input AXIS bus
      // Mux sample data depending on if we are finishing an odd length packet
      // or a regular beat with 2 paired samples.
      .in_tdata({end_of_packet,
                 (end_of_packet && input_count[0]) ? axis_stream_in.tdata : sample_holding_reg,
                 axis_stream_in.tdata}),
      .in_tvalid( ((input_state==S_INPUT_PHASE2) || (end_of_packet && input_count[0])) && ingress_beat),
      .in_tready(sfifo_not_full),

      // Output AXIS bus
      .out_tdata({sfifo_minimal_tlast,sfifo_minimal_tdata}),
      .out_tvalid(sfifo_minimal_tvalid),
      .out_tready(sfifo_minimal_tready),

      // Unused
      .space(space_sample),
      .occupied(occupied_sample)
      );

   // Unused
   wire [1:0] space_sample_min, occupied_sample_min;
   
   axis_minimal_fifo
     #(.WIDTH((IQ_WIDTH*4)+1))
   sample_fifo_minimal
     (
      .clk(clk),
      .rst(rst),
      // Input AXIS bus
      .in_tdata({sfifo_minimal_tlast,sfifo_minimal_tdata}),
      .in_tvalid(sfifo_minimal_tvalid),
      .in_tready(sfifo_minimal_tready),

      // Output AXIS bus
      .out_tdata({sfifo_tlast,sfifo_tdata}),
      .out_tvalid(sfifo_tvalid),
      .out_tready(sfifo_tready),

      // Unused
      .space(space_sample_min),
      .occupied(occupied_sample_min)
      );


   //-----------------------------------------------------------------------------
   //
   // Output State Machine
   //
   //-----------------------------------------------------------------------------
   
   enum                      {
                              S_OUTPUT_HEADER,
                              S_OUTPUT_TIME,
                              S_OUTPUT_SAMPLES
                              }  output_state;
   
   axis_t axis_pfifo(.clk(clk));
   
   always_ff @(posedge clk) begin
      if (rst) begin
         output_state <= S_OUTPUT_HEADER;
      end else begin
         case (output_state)
           //
           // Waiting for a valid header entry to emerge from tfifo.
           // when it does, transition to next state if room in output fifo
           // for header field this cycle.
           //
           S_OUTPUT_HEADER: begin
              if (tfifo_tvalid && axis_pfifo.tready)
                output_state <= S_OUTPUT_TIME;
              else
                output_state <= S_OUTPUT_HEADER;
           end
           //
           // Same header entry should still show valid on tfifo, transition
           // to next state if room in output fifo for time field this cycle
           //
           S_OUTPUT_TIME: begin
              if (tfifo_tvalid && axis_pfifo.tready)
                output_state <= S_OUTPUT_SAMPLES;
              else
                output_state <= S_OUTPUT_TIME;
           end
           //
           // Transition back to look for new header when we hit
           // tlast in sample fifo and room in output fifo for last sample pair.
           //
           S_OUTPUT_SAMPLES: begin
              if (sfifo_tvalid && sfifo_tlast && axis_pfifo.tready)
                output_state <= S_OUTPUT_HEADER;
              else
                output_state <= S_OUTPUT_SAMPLES;
           end
           //
           // Default same as S_OUTPUT_HEADER
           //
           default: begin
              if (tfifo_tvalid && axis_pfifo.tready)
                output_state <= S_OUTPUT_TIME;
              else
                output_state <= S_OUTPUT_HEADER;
           end

         endcase // case (output_state)
      end // else: !if(rst)
   end // always_ff @ (posedge clk)

   //
   // Sequence ID is reset every time that we dissable this module
   //
   //
   logic [7:0] seq_id;

   always_ff @(posedge clk)
     if (rst)
       seq_id <= 0;
     else if (!enable)
       seq_id <= 0;
     else if (axis_pfifo.tvalid && axis_pfifo.tready && axis_pfifo.tlast)
       seq_id <= seq_id + 1'b1;



   //-----------------------------------------------------------------------------
   //
   // Packet Framing Mux for INT16_COMPLEX packet types
   //
   //  63   56 55   48 47           32 31                            0
   // =================================================================
   // | Type  | SEQID |      Size     |           Flow ID             |
   // =================================================================
   // |                     Time                                      |
   // =================================================================
   // |      I0       |       Q0      |      I1       |      Q1       |
   // =================================================================
   //
   //-----------------------------------------------------------------------------
   wire [63:0] expanded_tdata;

   generate
      if (IQ_WIDTH==16) begin: no_shift
         assign expanded_tdata = sfifo_tdata[63:0];

      end else begin: left_shift_iq_data
         assign expanded_tdata = {
                                  sfifo_tdata[(IQ_WIDTH*4)-1:(IQ_WIDTH*3)],
                                  {16-IQ_WIDTH{1'b0}},
                                  sfifo_tdata[(IQ_WIDTH*3)-1:(IQ_WIDTH*2)],
                                  {16-IQ_WIDTH{1'b0}},
                                  sfifo_tdata[(IQ_WIDTH*2)-1:(IQ_WIDTH)],
                                  {16-IQ_WIDTH{1'b0}},
                                  sfifo_tdata[IQ_WIDTH-1:0],
                                  {16-IQ_WIDTH{1'b0}}
                                  };
      end
   endgenerate


   always_comb
     case(output_state)
       S_OUTPUT_HEADER: begin
          axis_pfifo.tdata = {(tfifo_tdata[78] ? packet_type_eob : packet_type),seq_id,tfifo_tdata[77:64],2'b00,flow_id};
          axis_pfifo.tvalid = tfifo_tvalid ;
          axis_pfifo.tlast = 1'b0;
          tfifo_tready = 1'b0;
          sfifo_tready = 1'b0;
       end
       S_OUTPUT_TIME: begin
          axis_pfifo.tdata = tfifo_tdata[63:0];
          axis_pfifo.tvalid = tfifo_tvalid;
          axis_pfifo.tlast = 1'b0;
          tfifo_tready = axis_pfifo.tready;
          sfifo_tready = 1'b0;
       end
       S_OUTPUT_SAMPLES: begin
          axis_pfifo.tdata = expanded_tdata; // MSB justify
          axis_pfifo.tvalid = sfifo_tvalid;
          axis_pfifo.tlast = sfifo_tlast;
          tfifo_tready = 1'b0;
          sfifo_tready = axis_pfifo.tready;
       end

       default: begin
          // Default to S_OUTPUT_HEADER
          axis_pfifo.tdata = {packet_type,seq_id,tfifo_tdata[76:64],3'b000,flow_id};
          axis_pfifo.tvalid = tfifo_tvalid;
          axis_pfifo.tlast = 1'b0;
          tfifo_tready = 1'b0;
          sfifo_tready = 1'b0;
       end
     endcase

   // Unused
   wire [PACKET_FIFO_SIZE:0] space_packet, occupied_packet;

   
   axis_fifo_wrapper
     #(
       .SIZE(PACKET_FIFO_SIZE)
       )
   packet_fifo
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_pfifo),
      .out_axis(axis_pkt_out),
      // Unused
      .space(space_packet),
      .occupied(occupied_packet)
      );

   //-----------------------------------------------------------------------------
   //
   // Generate Idle status flag
   //
   //-----------------------------------------------------------------------------
   always_ff @(posedge clk)
     if (rst) begin
        idle <= 1'b1;
     end else begin
        idle <= (~axis_pkt_out.tvalid) && (~enable) && (~axis_pfifo.tvalid) 
          && (~tfifo_tvalid) && (input_state == S_INPUT_IDLE) && (burst_state == S_NEW_BURST);
     end

endmodule // axis_stream_to_pkt
