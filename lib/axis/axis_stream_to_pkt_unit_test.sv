//-------------------------------------------------------------------------------
// File:    axis_stream_to_pkt_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_stream_to_pkt.sv"

module axis_stream_to_pkt_unit_test;
   timeunit 1ns;
   timeprecision 1ps;
   import drat_protocol::*;
   import svunit_pkg::svunit_testcase;

   string name = "axis_stream_to_pkt_ut";
   svunit_testcase svunit_ut;

   logic clk;
   logic rst;
   logic reset_timestamp;


   // Output bus
   pkt_stream_t out(.clk(clk));
   // pkt_stream_t in(.clk(clk));

   // Data structure holds input header
   pkt_header_t header_in;
   // Data structure holds output header
   pkt_header_t header_out;

   // Streaming sample interface
   wire [15:0] in_i, in_q;

   wire        in_valid;
   wire        in_last;

   // CSR signals
   logic        enable;
   logic [12:0] packet_size; // Packet size expressed in 64bit words including headers
   logic [31:0] flow_id; // DRaT Flow ID for this flow (union of src + dst)
   logic 	flow_id_changed; // Pulse high one cycle when flow_id updated.
   wire 	idle;
   wire 	overflow;
   // Time
   logic [63:0] current_time;


   wire [31:0]  status;

   logic [63:0] beat_in, beat1, beat2;
   logic        tlast_in, tlast_out;

   // Monitor space in test buffer
   int          space;
   //
   int          x;
   int          timeout;

   int          packet_count_in;
   int          packet_count_out;

   logic        ready_to_test;

   logic [31:0] load_tdata;
   logic 	load_tlast;
   logic 	load_tready;
   logic 	load_tvalid;

   Packet test_packets[];



   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
   end

   always begin
     #5 clk <= ~clk;
   end

   //
   // Provide timestamp that incremenst on sample clock domain.
   //
   //initial begin
   //   current_time <= 0;
   //end

   always_ff @(posedge clk) begin
      if (rst)
	current_time <= 0;
      else if (reset_timestamp)
	current_time <= 0;
      else
	current_time <= current_time + 1 ;
   end


   //-------------------------------------------------------------------------------
   // Buffer input sample stream a.k.a Golden payload (Note doesn't drive UUT directly just stores test stimulus.
   // FIFO is 32 bits wide for one complex 16b sample per clock.
   //-------------------------------------------------------------------------------


   axis_fifo
     #(.WIDTH(33),.SIZE(11))
   axis_fifo_i0
     (.clk(clk), .rst(rst),
      .in_tdata({load_tlast,load_tdata}),
      .in_tvalid(load_tvalid),
      .in_tready(load_tready),
      .out_tdata({in_last,in_i,in_q}),
      .out_tvalid(in_valid),
      .out_tready(ready_to_test), //IJB Revisit tready
      .space(),
      .occupied());



   //===================================
   // This is the UUT that we're
   // running the Unit Tests on
   //===================================
/*
   axis_stream_to_pkt
     #(
       .TIME_FIFO_SIZE(4),
       .SAMPLE_FIFO_SIZE(13),
       .PACKET_FIFO_SIZE(8),
       .IQ_WIDTH(16)
       )
   my_axis_stream_to_pkt
     (
      .clk(clk),
      .rst(rst),
      //-------------------------------------------------------------------------------
      // CSR registers
      //-------------------------------------------------------------------------------
      .enable(enable),
      .packet_size(packet_size), // Packet size expressed in 64bit words including headers
      .flow_id(flow_id), // DRaT Flow ID for this flow (union of src + dst)
      .flow_id_changed(flow_id_changed), // Pulse high one cycle when flow_id updated.
      // Status Flags
      .idle(idle),
      .overflow(overflow),
      // System Time
      .current_time(current_time),
      //-------------------------------------------------------------------------------
      // Streaming sample Input Bus
      //-------------------------------------------------------------------------------
      .in_clk(clk),
      .in_i(in_i),
      .in_q(in_q),
      .in_valid(in_valid && ready_to_test),
      //-------------------------------------------------------------------------------
      // AXIS Output Bus
      //-------------------------------------------------------------------------------
      .out_tdata(out.axis.tdata),
      .out_tvalid(out.axis.tvalid),
      .out_tlast(out.axis.tlast),
      .out_tready(out.axis.tready)
      );

   */

   axis_stream_to_pkt_wrapper
     #(
       .TIME_FIFO_SIZE(4),
       .SAMPLE_FIFO_SIZE(13),
       .PACKET_FIFO_SIZE(8),
       .IQ_WIDTH(16)
       )
   my_axis_stream_to_pkt
     (
      .clk(clk),
      .rst(rst),
      //-------------------------------------------------------------------------------
      // CSR registers
      //-------------------------------------------------------------------------------
      .enable(enable),
      .packet_size(packet_size), // Packet size expressed in 64bit words including headers
      .flow_id(flow_id), // DRaT Flow ID for this flow (union of src + dst)
      .flow_id_changed(flow_id_changed), // Pulse high one cycle when flow_id updated.
      // Status Flags
      .idle(idle),
      .overflow(overflow),
      // System Time
      .current_time(current_time),
      //-------------------------------------------------------------------------------
      // Streaming sample Input Bus
      //-------------------------------------------------------------------------------
      .in_clk(clk),
      .in_i(in_i),
      .in_q(in_q),
      .in_valid(in_valid && ready_to_test),
      //-------------------------------------------------------------------------------
      // AXIS Output Bus
      //-------------------------------------------------------------------------------
      .out_axis(out.axis)
      );


  //===================================
  // Build
  //===================================
  function void build();
    svunit_ut = new(name);
  endfunction


  //===================================
  // Setup for running the Unit Tests
  //===================================
  task setup();
    svunit_ut.setup();
    /* Place Setup Code Here */
       // Reset UUT
     @(posedge clk);
     rst <= 1'b1;
     // Bring CSR"s to reset like values.
     ready_to_test <= 0;
     enable <= 0;
     packet_size <= 0;
     flow_id <= 0;
     flow_id_changed <= 0;
     reset_timestamp <= 0;

     repeat(10) @(posedge clk);
     rst <= 1'b0;
     idle_all();


  endtask


  //===================================
  // Here we deconstruct anything we
  // need after running the Unit Tests
  //===================================
  task teardown();
    svunit_ut.teardown();
    /* Place Teardown Code Here */
  endtask



  //===================================
  // All tests are defined between the
  // SVUNIT_TESTS_BEGIN/END macros
  //
  // Each individual test must be
  // defined between `SVTEST(_NAME_)
  // `SVTEST_END
  //
  // i.e.
  //   `SVTEST(mytest)
  //     <test code>
  //   `SVTEST_END
  //===================================
  `SVUNIT_TESTS_BEGIN

  //-------------------------------------------------------------------------------
  // Valid input sample every clock cycle. Timestamp initialized to 0.
  // Sample stream is ramp in I & Q
  //-------------------------------------------------------------------------------
  `SVTEST(sample_every_cycle_ramp)
  `INFO("Testing one sample per cycle with ramp payload into packets");
   fork
      begin: mm_source_thread
         space = 'd1024;
         // Set up input packet header
         packet_count_in = 0;
         test_packets = new[1];
         // Allocate packet and Initialize header: INT16_COMPLEX
         test_packets[0] = new;
         test_packets[0].init;
         test_packets[0].set_flow_src(INPUT);
         test_packets[0].set_flow_dst(OUTPUT);
         // Unsigned value constrained between min packet size and buffer size.
         // (whole number of beats converted to bytes)
         //test_packets[packet_count_in].set_length (beats_to_bytes({$random} % (space-3) + 3));
	 test_packets[0].set_length(beats_to_bytes('d128)); // fixed 128beat packet size
         space = space - bytes_to_beats(test_packets[packet_count_in].get_length);
         // Generate ramped payload.
         test_packets[0].ramp;

         test_packets[0].rewind_payload;
	 // Get 64b payload beats and pack them into two 32b FIFO entries
         for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_in].get_length) - 2) ; x = x + 1)
	    begin
		beat_in = test_packets[0].get_beat;
	        push_fifo(beat_in[63:32],0);
	        push_fifo(beat_in[31:0],0);
            end

         while (space > 0) begin
            packet_count_in = packet_count_in + 1;
            // Preserve existing packets whilst expanding list
            test_packets = new[packet_count_in+1] (test_packets);
            // Copy header from previous packet and increment sequence ID
            test_packets[packet_count_in] = new;
            test_packets[packet_count_in].set_header(test_packets[packet_count_in-1].get_header);
            test_packets[packet_count_in].inc_seq_id;
            // Add delta to timestamp
            test_packets[packet_count_in].set_timestamp(test_packets[packet_count_in].get_timestamp +
				  ((bytes_to_beats(test_packets[packet_count_in].get_length)-2)*2)); // Add sample count of last packet
            // Unsigned value constrained between min packet size and remaining buffer size.
            //test_packets[packet_count_in].set_length ('d128)); // fixed 128beat packet size
            space = space - bytes_to_beats(test_packets[packet_count_in].get_length);

            // Generate ramped payload.
            test_packets[packet_count_in].ramp;

            test_packets[packet_count_in].rewind_payload;
	    // Get 64b payload beats and pack them into two 32b FIFO entries
            for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_in].get_length) - 3) ; x = x + 1)
	      begin
		 beat_in = test_packets[packet_count_in].get_beat;
	         push_fifo(beat_in[63:32],0);
		 push_fifo(beat_in[31:0],0);
              end
	    beat_in = test_packets[packet_count_in].get_beat;
	    push_fifo(beat_in[63:32],0);
	    if (space > 0)
	      push_fifo(beat_in[31:0],0);
 	    else
	      push_fifo(beat_in[31:0],1); // Set tlast on last sample
         end // while (space > 0)
         `INFO("Test sample stream buffered in FIFO. Now enable packetization.");
	 @(posedge clk);
         // Bring CSRs to reset like values.
         ready_to_test <= 0;
         enable <= 0;
         packet_size <= bytes_to_beats(test_packets[0].get_length);
         flow_id <= test_packets[0].get_flow_id;
         flow_id_changed <= 1;
	 @(posedge clk);
         flow_id_changed <= 0;
	 reset_timestamp <= 1;
	 @(posedge clk);
	 reset_timestamp <= 0; // Starts timestamp counter running
	 enable <= 1; // Starts packetization block running.
         ready_to_test <= 1; // Modulates input data flow

         while (in_last != 1)
	   @(posedge clk);

         `INFO("All test sample stream written to interface. Source thread exits.");
         ready_to_test <= 0;
      end // block: mm_source_thread

      begin: pkt_sink_thread
         while (!ready_to_test) @(posedge clk);
          `INFO("Receiving thread now armed.");
         //
         // Access AXIS egress interface to get packets.
         //
         packet_count_out = 0;

         while (packet_count_out <= packet_count_in)
           begin
              // Packet Header
	      out.pull_beat(beat1,tlast_out);
	      `FAIL_UNLESS(tlast_out === 1'b0);
	      out.pull_beat(beat2,tlast_out);
	      `FAIL_UNLESS(tlast_out === 1'b0);
              // Compare received header with reference.
              header_out = populate_header({beat1,beat2});
              `INFO("Received:");
              print_header(header_out);
              `INFO("Reference:");
              print_header(test_packets[packet_count_out].get_header);
              `FAIL_UNLESS(header_compare(test_packets[packet_count_out].get_header,header_out));
              // Get packet payload and compare with reference
              test_packets[packet_count_out].rewind_payload;
              for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_out].get_length) - 3) ; x = x + 1) begin
            	 out.pull_beat(beat1,tlast_out);
                 `FAIL_UNLESS(tlast_out === 1'b0);
                 `FAIL_UNLESS_EQUAL(beat1,test_packets[packet_count_out].get_beat);
              end
              out.pull_beat(beat1,tlast_out);
              `FAIL_UNLESS(tlast_out === 1'b1);
              `FAIL_UNLESS_EQUAL(beat1,test_packets[packet_count_out].get_beat);
              packet_count_out = packet_count_out + 1;
           end // while (packet_count_out < packet_count_in)
         `INFO("All packetized sample payload received correctly, with correct header data.");
         disable watchdog_thread;
      end // block: pkt_sink_thread

      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end

   join
   `SVTEST_END

 //-------------------------------------------------------------------------------
 // Valid input sample every other clock cycle. Timestamp initialized to 0.
 // Sample stream is ramp in I & Q
 //-------------------------------------------------------------------------------

  `SVTEST(sample_every_other_cycle_ramp)
  `INFO("Testing one sample every other cycle with ramp payload into packets");
   fork
      begin: mm_source_thread
         space = 'd1024;
         // Set up input packet header
         packet_count_in = 0;
         test_packets = new[1];
         // Allocate packet and Initialize header: INT16_COMPLEX
         test_packets[0] = new;
         test_packets[0].init;
         test_packets[0].set_flow_src(INPUT);
         test_packets[0].set_flow_dst(OUTPUT);
	 test_packets[packet_count_in].set_timestamp(1); // First sample arrives at timestamp 1

         // Unsigned value constrained between min packet size and buffer size.
         // (whole number of beats converted to bytes)
         //test_packets[packet_count_in].set_length (beats_to_bytes({$random} % (space-3) + 3));
	 test_packets[0].set_length(beats_to_bytes('d128)); // fixed 128beat packet size
         space = space - bytes_to_beats(test_packets[packet_count_in].get_length);
         // Generate ramped payload.
         test_packets[0].ramp;

         test_packets[0].rewind_payload;
	 // Get 64b payload beats and pack them into two 32b FIFO entries
         for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_in].get_length) - 2) ; x = x + 1)
	    begin
		beat_in = test_packets[0].get_beat;
	        push_fifo(beat_in[63:32],0);
	        push_fifo(beat_in[31:0],0);
            end

         while (space > 0) begin
            packet_count_in = packet_count_in + 1;
            // Preserve existing packets whilst expanding list
            test_packets = new[packet_count_in+1] (test_packets);
            // Copy header from previous packet and increment sequence ID
            test_packets[packet_count_in] = new;
            test_packets[packet_count_in].set_header(test_packets[packet_count_in-1].get_header);
            test_packets[packet_count_in].inc_seq_id;
            // Add delta to timestamp
            test_packets[packet_count_in].set_timestamp(test_packets[packet_count_in].get_timestamp +
				  ((bytes_to_beats(test_packets[packet_count_in].get_length)-2)*4)); // Add sample count of last packet
            // Unsigned value constrained between min packet size and remaining buffer size.
            //test_packets[packet_count_in].set_length ('d128)); // fixed 128beat packet size
            space = space - bytes_to_beats(test_packets[packet_count_in].get_length);

            // Generate ramped payload.
            test_packets[packet_count_in].ramp;

            test_packets[packet_count_in].rewind_payload;
	    // Get 64b payload beats and pack them into two 32b FIFO entries
            for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_in].get_length) - 3) ; x = x + 1)
	      begin
		 beat_in = test_packets[packet_count_in].get_beat;
	         push_fifo(beat_in[63:32],0);
		 push_fifo(beat_in[31:0],0);
              end
	    beat_in = test_packets[packet_count_in].get_beat;
	    push_fifo(beat_in[63:32],0);
	    if (space > 0)
	      push_fifo(beat_in[31:0],0);
 	    else
	      push_fifo(beat_in[31:0],1); // Set tlast on last sample
         end // while (space > 0)
         `INFO("Test sample stream buffered in FIFO. Now enable packetization.");
	 @(posedge clk);
         // Bring CSRs to reset like values.
         ready_to_test <= 0;
         enable <= 0;
         packet_size <= bytes_to_beats(test_packets[0].get_length);
         flow_id <= test_packets[0].get_flow_id;
         flow_id_changed <= 1;
	 @(posedge clk);
         flow_id_changed <= 0;
	 reset_timestamp <= 1;
	 @(posedge clk);
	 reset_timestamp <= 0; // Starts timestamp counter running
	 enable <= 1; // Starts packetization block running.
	 @(posedge clk);
         ready_to_test <= 1;// Modulates input data flow

         while (in_last != 1) begin
	    @(posedge clk);
            ready_to_test <= 0;
	    @(posedge clk);
	    ready_to_test <= 1;
	 end
	 // Run for 2 cycles to allow state machines to get last packet
	 @(posedge clk);
         ready_to_test <= 0;
	 @(posedge clk);
	 ready_to_test <= 1;
	 @(posedge clk);
         `INFO("All test sample stream written to interface. Source thread exits.");
         ready_to_test <= 0;
      end // block: mm_source_thread

      begin: pkt_sink_thread
         while (!ready_to_test) @(posedge clk);
          `INFO("Receiving thread now armed.");
         //
         // Access AXIS egress interface to get packets.
         //
         packet_count_out = 0;

         while (packet_count_out <= packet_count_in)
           begin
              // Packet Header
	      out.pull_beat(beat1,tlast_out);
	      `FAIL_UNLESS(tlast_out === 1'b0);
	      out.pull_beat(beat2,tlast_out);
	      `FAIL_UNLESS(tlast_out === 1'b0);
              // Compare received header with reference.
              header_out = populate_header({beat1,beat2});
              `INFO("Received:");
              print_header(header_out);
              `INFO("Reference:");
              print_header(test_packets[packet_count_out].get_header);
              `FAIL_UNLESS(header_compare(test_packets[packet_count_out].get_header,header_out));
              // Get packet payload and compare with reference
              test_packets[packet_count_out].rewind_payload;
              for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_out].get_length) - 3) ; x = x + 1) begin
            	 out.pull_beat(beat1,tlast_out);
                 `FAIL_UNLESS(tlast_out === 1'b0);
                 `FAIL_UNLESS_EQUAL(beat1,test_packets[packet_count_out].get_beat);
              end
              out.pull_beat(beat1,tlast_out);
              `FAIL_UNLESS(tlast_out === 1'b1);
              `FAIL_UNLESS_EQUAL(beat1,test_packets[packet_count_out].get_beat);
              packet_count_out = packet_count_out + 1;
           end // while (packet_count_out < packet_count_in)
         `INFO("All packetized sample payload received correctly, with correct header data.");
         disable watchdog_thread;
      end // block: pkt_sink_thread

      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end

   join
   `SVTEST_END

  `SVUNIT_TESTS_END


   // Task: idle_all()
   // Cause all AXIS buses to go idle.
   task idle_all();
      out.axis.idle_slave();
      //in_fifo.axis.idle_slave();
   endtask // idle_all


   task automatic push_fifo;
      input [31:0] data;
      input 	   last;

      begin
	 load_tvalid <= 0;
	 @(posedge clk);
	 while (load_tready != 1)
	   @(posedge clk);
	 load_tvalid <= 1;
	 load_tdata <= data;
	 load_tlast <= last;

	 @(posedge clk);
	 load_tvalid <= 0;
      end
   endtask




endmodule
