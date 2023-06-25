//----------------------------------------------------------------------------
// File:    axis_stream_to_pkt.sv
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
// Add timestamp to each packet. Time stamp comes from external free running counter.
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
`include "global_defs.svh"

module axis_stream_to_pkt
  #(
    parameter TIME_FIFO_SIZE=4,
    parameter SAMPLE_FIFO_SIZE=13,
    parameter PACKET_FIFO_SIZE=8,
    parameter IQ_WIDTH=16 // Width of IQ samples from Datapath.
    )

   (
    input logic 	       clk,
    input logic 	       rst,
    // Control signal (Just support free run for now, not time triggered)
    input logic 	       enable,
    // Populate DRaT Header fields
    input logic [15:3] 	       packet_size, // Packet size expressed in 64bit words including headers
    input logic [31:0] 	       flow_id, // DiRT Flow ID for this flow (union of src + dst)
    input logic 	       flow_id_changed, // Pulse high one cycle when flow_id updated.
    // Status Flags
    output logic 	       idle,
    output logic 	       overflow,
    // System Time
    input logic [63:0] 	       current_time,
    //
    // Streaming IQ Sample bus.
    // Fractional integer data
    // Valid signal to qualify. Not back-pressurable.
    //
    input logic 	       in_clk,
    input logic [IQ_WIDTH-1:0] in_i,
    input logic [IQ_WIDTH-1:0] in_q,
    input logic 	       in_valid,
    //
    // DiRT Packetized Output AXIS Bus
    //
    output logic [63:0]        out_tdata,
    output logic 	       out_tvalid,
    input logic 	       out_tready,
    output logic 	       out_tlast
    );

   import dirt_protocol::*;
   
   // Hardcode all packets as DiRT 16bit IQ type for now.
   pkt_type_t   packet_type;
   assign packet_type = INT16_COMPLEX;
   
   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Input State machine (Mealy Machine).
   // Always have even number of samples in a packet to simplify design.
   //
   /////////////////////////////////////////////////////////////////////////////////////////////////////
   localparam INPUT_IDLE=2'h0;
   localparam INPUT_PHASE1=2'h1;
   localparam INPUT_PHASE2=2'h2;

   logic [1:0]      input_state;
   logic [12:0]     input_count;


   always_ff @(posedge clk)
     if (rst) begin
        input_state <= INPUT_IDLE;
        input_count <= 0;
     end else begin
        case(input_state)
          //
          INPUT_IDLE: begin
             if (!enable) begin
                input_state <= INPUT_IDLE;
             end else if (in_valid) begin
                // 1st sample of a packet gets written to holding reg as we transition from this state.
                input_count <= 3;
                input_state <= INPUT_PHASE2;
             end else
               input_state <= INPUT_IDLE;
          end
          //
          // Wait for sync'ed sample to transfer to holding.
          //
          INPUT_PHASE1: begin
             if (in_valid) begin
                input_count <= input_count + 1'b1;
                input_state <= INPUT_PHASE2;
             end else begin
                input_state <= INPUT_PHASE1;
             end
          end
          //
          // Wait for sync'ed sample to send to FIFO with holding contents.
          // If count reached then go idle.
          //
          INPUT_PHASE2: begin
             if (in_valid) begin
                if (input_count >= packet_size) begin
                   input_state <= INPUT_IDLE;
                end else begin
                   input_state <= INPUT_PHASE1;
                end
             end else begin
                input_state <= INPUT_PHASE2;
             end
          end // case: INPUT_PHASE2
        endcase // case (input_state)
     end // else: !if(rst)


   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Buffer snapshots of current_time. Freeze time as first sample enters streaming interface in "enabled" state.
   // Frozen time is inserted into FIFO as the last sample of a "to-yet-be-framed" packet
   // is placed into the sample FIFO. This ensures that we have all the packet body already in a high speed FIFO ready
   // to burst at wire rate downstream.
   //
   /////////////////////////////////////////////////////////////////////////////////////////////////////
   logic [63:0]           freeze_time;
   wire [(64+13-1):0]   tfifo_tdata;
   wire                 tfifo_tvalid;
   logic                  tfifo_tready;
   wire                 tfifo_not_full;

   always_ff @(posedge clk)
     if (rst)
       freeze_time <= 64'h0;
     else if (input_state==INPUT_IDLE) begin
        freeze_time <= current_time; // Stop updating this and freeze as state m/c goes non-idle
     end


   axis_fifo
     #(
       .WIDTH(64+13),
       .SIZE(TIME_FIFO_SIZE) // Minimal.
       )
   time_fifo
     (
      .clk(clk),
      .rst(rst),
      // Input AXIS bus
      .in_tdata({input_count,freeze_time}),
      .in_tvalid((input_count >= packet_size) && (input_state==INPUT_PHASE2) && in_valid),
      .in_tready(tfifo_not_full),

      // Output AXIS bus
      .out_tdata(tfifo_tdata),
      .out_tvalid(tfifo_tvalid),
      .out_tready(tfifo_tready),

      // Unused
      .space(),
      .occupied()
      );

   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Buffer samples in DSP clock domain before forming packets out of them
   //
   /////////////////////////////////////////////////////////////////////////////////////////////////////
   logic [(2*IQ_WIDTH)-1:0]           sample_holding_reg;
   wire [(4*IQ_WIDTH)-1:0] 	      sfifo_tdata;
   wire                               sfifo_tvalid;
   logic 			      sfifo_tready;
   wire                               sfifo_tlast;
   wire                               sfifo_not_full;

   wire [(4*IQ_WIDTH)-1:0] 	      sfifo_minimal_tdata;
   wire                               sfifo_minimal_tvalid;
   wire 			      sfifo_minimal_tready;
   wire                               sfifo_minimal_tlast;

   // Always grab input data when its valid.
   // We will only use the holding data when state is INPUT_PHASE2 and
   // the input data is valid...which implies it currently holds valid data from INPUT_PHASE1.
   // Other times its contents will be overwritten without ever being read.
  always_ff @(posedge clk) begin
      if (rst)
        sample_holding_reg <= 0;
      else if (in_valid) begin
         sample_holding_reg <= {in_i,in_q};
      end
   end

   axis_fifo
     #(.WIDTH((IQ_WIDTH*4)+1),
       .SIZE(SAMPLE_FIFO_SIZE))
   sample_fifo
     (
      .clk(clk),
      .rst(rst),
      // Input AXIS bus
      .in_tdata({(input_count >= packet_size),sample_holding_reg,in_i,in_q}),
      .in_tvalid( (input_state==INPUT_PHASE2) && in_valid),
      .in_tready(sfifo_not_full),

      // Output AXIS bus
      .out_tdata({sfifo_minimal_tlast,sfifo_minimal_tdata}),
      .out_tvalid(sfifo_minimal_tvalid),
      .out_tready(sfifo_minimal_tready),

      // Unused
      .space(),
      .occupied()
      );

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
      .out_tready(sfifo_tready)
      );


   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Output State Machine
   //
   /////////////////////////////////////////////////////////////////////////////////////////////////////
   localparam OUTPUT_HEADER=2'h0;
   localparam OUTPUT_TIME=2'h1;
   localparam OUTPUT_SAMPLES=2'h2;

   logic [63:0] pfifo_tdata;
   logic        pfifo_tvalid;
   wire 	pfifo_tready;
   logic        pfifo_tlast;


   logic [1:0]  output_state;


   always_ff @(posedge clk) begin
      if (rst) begin
         output_state <= OUTPUT_HEADER;
      end else begin
         case (output_state)
           //
           // Waiting for a valid header entry to emerge from tfifo.
           // when it does, transition to next state if room in output fifo
           // for header field this cycle.
           //
           OUTPUT_HEADER: begin
              if (tfifo_tvalid && pfifo_tready && ~flow_id_changed) // Avid flow_id_changed race condition
                output_state <= OUTPUT_TIME;
              else
                output_state <= OUTPUT_HEADER;
           end
           //
           // Same header entry should still show valid on tfifo, transition
           // to next state if room in output fifo for time field this cycle
           //
           OUTPUT_TIME: begin
              if (tfifo_tvalid && pfifo_tready)
                output_state <= OUTPUT_SAMPLES;
              else
                output_state <= OUTPUT_TIME;
           end
           //
           // Transition back to look for new header when we hit
           // tlast in sample fifo and room in output fifo for last sample pair.
           //
           OUTPUT_SAMPLES: begin
              if (sfifo_tvalid && sfifo_tlast && pfifo_tready)
                output_state <= OUTPUT_HEADER;
              else
                output_state <= OUTPUT_SAMPLES;
           end
           //
           // Default same as OUTPUT_HEADER
           //
           default: begin
              if (tfifo_tvalid && pfifo_tready)
                output_state <= OUTPUT_TIME;
              else
                output_state <= OUTPUT_HEADER;
           end

         endcase // case (output_state)
      end // else: !if(rst)
   end // always_ff @ (posedge clk)

   //
   // Sequence ID is reset every time that we dissable this module or the flow_id changes.
   //
   //
   logic [7:0] seq_id;

   always_ff @(posedge clk)
     if (rst)
       seq_id <= 0;
     else if (!enable || flow_id_changed)
       seq_id <= 0;
     else if (pfifo_tvalid && pfifo_tready && pfifo_tlast)
       seq_id <= seq_id + 1'b1;



   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Packet Framing Mux
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
   /////////////////////////////////////////////////////////////////////////////////////////////////////
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
       OUTPUT_HEADER: begin
          pfifo_tdata = {packet_type,seq_id,tfifo_tdata[76:64],3'b000,flow_id};
          pfifo_tvalid = tfifo_tvalid && ~flow_id_changed; // Avoid flow_id_changed race condition
          pfifo_tlast <= 1'b0;
          tfifo_tready <= 1'b0;
          sfifo_tready <= 1'b0;
       end
       OUTPUT_TIME: begin
          pfifo_tdata = tfifo_tdata[63:0];
          pfifo_tvalid = tfifo_tvalid;
          pfifo_tlast <= 1'b0;
          tfifo_tready <= pfifo_tready;
          sfifo_tready <= 1'b0;
       end
       OUTPUT_SAMPLES: begin
          pfifo_tdata = expanded_tdata; // MSB justify
          pfifo_tvalid = sfifo_tvalid;
          pfifo_tlast <= sfifo_tlast;
          tfifo_tready <= 1'b0;
          sfifo_tready <= pfifo_tready;
       end

       default: pfifo_tdata = {packet_type,seq_id,tfifo_tdata[76:64],3'b000,flow_id};
     endcase

   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Buffer framed packets before egress
   //
   /////////////////////////////////////////////////////////////////////////////////////////////////////

   axis_fifo
     #(
       .WIDTH(65),
       .SIZE(PACKET_FIFO_SIZE)
       )
   packet_fifo
     (
      .clk(clk),
      .rst(rst),
      // Input AXIS bus
      .in_tdata({pfifo_tlast,pfifo_tdata}),
      .in_tvalid(pfifo_tvalid),
      .in_tready(pfifo_tready), //ignore

      // Output AXIS bus
      .out_tdata({out_tlast,out_tdata}),
      .out_tvalid(out_tvalid),
      .out_tready(out_tready),

      // Unused
      .space(),
      .occupied()
      );

   /////////////////////////////////////////////////////////////////////////////////////////////////////
   //
   // Generate Overflow flag
   //
   /////////////////////////////////////////////////////////////////////////////////////////////////////
   always_ff @(posedge clk)
     if (rst) begin
        overflow <= 1'b0;
        idle <= 1'b1;
     end else begin
        overflow <= (~sfifo_not_full) || (~tfifo_not_full);
        idle <= (~out_tvalid) && (~enable) && (~pfifo_tvalid) && (~tfifo_tvalid) && (input_state == INPUT_IDLE);
     end

endmodule // axis_stream_to_pkt
