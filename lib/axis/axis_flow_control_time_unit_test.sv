//-------------------------------------------------------------------------------
// File:    axis_flow_control_time_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
//
//
//-------------------------------------------------------------------------------

`include "global_defs.svh"
`include "svunit_defines.svh"
`include "axis_flow_control_time.sv"
`include "drat_protocol.sv"

module axis_flow_control_time_unit_test;
   import drat_protocol::*;
   import svunit_pkg::svunit_testcase;
   
   timeunit 1ns;
   timeprecision 1ps;

   string name = "axis_flow_control_time_ut";
   svunit_testcase svunit_ut;
   
   logic clk;
   logic rst;

   // Pre-Buffer Input Bus
   pkt_stream_t axis_stimulus_pre(.clk(clk));
   // Bus between stimulus buffer and valve
   pkt_stream_t axis_stimulus_post(.clk(clk));
   // Bus between stimulus valve and UUT
   pkt_stream_t axis_stimulus_gated(.clk(clk));

   // DUT Output bus
   pkt_stream_t axis_response_gated(.clk(clk));
   // Bus between response vavle and buffer
   pkt_stream_t axis_response_pre(.clk(clk));
   // Post Buffer Output bus
   pkt_stream_t axis_response_post(.clk(clk));

   axis_t #(.WIDTH(64)) axis_time(.clk(clk));
   axis_t #(.WIDTH(64)) axis_time_in(.clk(clk));

   // enables DUT operation
   logic csr_enable;
   // Write this register with delta from system time to release packets downstream
   logic [31:0] csr_time_delta;
   // Systemwide time
   logic [63:0] system_time;
   logic        reset_time;

   // Declarations for Stimulus Thread(s)
   logic        enable_stimulus;
   logic        enable_response;
   logic        ready_to_test;
   DRaTPacket       stimulus_packet;
   // Declarations for Response Thread(s)
   DRaTPacket       golden_packet, response_packet;
   logic [63:0] response_time;

   // Watchdog
   int 		timeout;
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
   // Provide time that increments on sample clock domain.
   //

   always_ff @(posedge clk) begin
      if (rst)
	system_time <= 0;
      else if (reset_time)
	system_time <= 0;
      else
	system_time <= system_time + 1 ;
   end




   //-------------------------------------------------------------------------------
   // Buffer input sample stream
   // FIFO is 32 bits wide for one complex 16b sample per clock.
   //-------------------------------------------------------------------------------

   axis_fifo_wrapper
     #(.SIZE(10))
   axis_fifo_stimulus_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_stimulus_pre.axis),
      .out_axis(axis_stimulus_post.axis),
      .space(),
      .occupied()
      );



   axis_valve axis_valve_stimulus_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_stimulus_post.axis),
      .out_axis(axis_stimulus_gated.axis),
      .enable(enable_stimulus)
      );

   //===================================
   // This is the UUT that we're
   // running the Unit Tests on
   //===================================

   axis_flow_control_time axis_flow_control_time_i
     (
      .clk(clk),
      .rst(rst),
      // Control/Status Register interface
      .csr_enable(csr_enable),
      .csr_time_delta(csr_time_delta),
      // Current System Time
      .system_time(system_time),
      // Upstream packet flow in
      .axis_in(axis_stimulus_gated.axis),
      // Downstream packet flow out
      .axis_out(axis_response_gated.axis)
      );

   //-------------------------------------------------------------------------------
   // Buffer output response sample stream with dispatch time metadata
   //-------------------------------------------------------------------------------
   axis_valve axis_valve_response_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_response_gated.axis),
      .out_axis(axis_response_pre.axis),
      .enable(enable_response)
      );

   axis_fifo_wrapper
     #(.SIZE(11))
   axis_fifo_response_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_response_pre.axis),
      .out_axis(axis_response_post.axis),
      .space(),
      .occupied()
      );

   // Grab timestamps in this FIFO for each response beat so we can prove correct "timeliness"
   always_comb begin
      axis_time_in.tdata = system_time;
      axis_time_in.tvalid = axis_response_pre.axis.tvalid;
      axis_time_in.tlast = 0;
   end

   axis_fifo_wrapper
     #(.SIZE(11))
   axis_time_fifo_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(axis_time_in),
      .out_axis(axis_time),
      .space(),
      .occupied()
      );



   //-------------------------------------------------------------------------------
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
      rst <= 1'b1;
      csr_enable <= 0;
      csr_time_delta <= 32'd0;
      reset_time <= 1'b1;
      // Open all valves by default
      enable_stimulus <= 1'b1;
      enable_response <= 1'b1;
      // Take all bench AXIS buses to a quiescent state
      idle_all();
      // De-assert reset after 10 clock cycles.
      @(posedge clk);
      repeat(10) @(posedge clk);
      rst <= 1'b0;

   endtask

   //===================================
   // Here we deconstruct anything we 
   // need after running the Unit Tests
   //===================================
   task teardown();
      svunit_ut.teardown();
      /* Place Teardown Code Here */
   endtask // teardown
   
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
   // Simple Test. Stream one burst with no throttling.
   //
   // Configured as follows:
   // start_time = 1000
   // packet_size = 10 samples
   // flow_id = {SRC0,DST0}
   // time_per_pkt = 10 (Sample_rate=clk_rate)
   // burst_size = 100 (10 packets)
   //
   //-------------------------------------------------------------------------------
   `SVTEST(burst_10pkts_of_10samples_1clkpersamp)
   `INFO("One burst of 10 good packets of INT16_COMPLEX");
   fork
      begin: load_stimulus
         // Setup this test:
         reset_time <= 1'b1; // Keep system time in reset whilst we setup up stimulus payload.
         csr_enable <= 0;
         csr_time_delta <= 32'd500; // Release 500 clock ticks before scheduled time.
         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Build 100 sample test pattern using ramp
         // Create Objects
         stimulus_packet = new;
         // Initialize header fields with default values
         stimulus_packet.init;
         // Overide FlowID
         stimulus_packet.set_flow_src(SRC0);
         stimulus_packet.set_flow_dst(DST0);
         // Set packet length to be header plus 5 beats of 2 complex samples
         stimulus_packet.set_length(beats_to_bytes(2+5));
         // Set timestamp of first packet to be 1000...
         stimulus_packet.set_timestamp(1000);
         // Explict set packet type to INT16_COMPLEX
         stimulus_packet.set_packet_type(INT16_COMPLEX);
         for (integer i = 0; i < 10; i++) begin
            $display("Stimulus Packet %d",i);
            // Initialize ramp waveform start value to zero on first pass
            stimulus_packet.ramp(i===0);
            if (i === 9) begin
               // End of Burst Reached.
               stimulus_packet.set_packet_type(INT16_COMPLEX_EOB);
            end
            // Push stimulus packet onto stimulus AXIS bus
            axis_stimulus_pre.push_pkt(stimulus_packet);
            // Increment Sequence Number
            stimulus_packet.inc_seq_id;
            // Increment Packet Time
            stimulus_packet.set_timestamp(stimulus_packet.get_timestamp() + 10);
         end // for (integer i = 0; i < 10; i++)
         //
         // Stimulus fully loaded, initialize system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         // Enable configured sub-system operation
         csr_enable <= 1;
         @(negedge clk);
         // Realase system clock to free run
         reset_time <= 1'b0;
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         $display("one_burst_one_clk_per_samp: Stimulus Done");
         //
      end // block: load_stimulus
      //
      begin: read_response
         //
         // This simulation should produce 10 packets of 10 samples containing a complex ramp waveform.
         // It should all be a single burst and each sample should increment the clock by one.
         // They should appear on the response bus very shortly after the threshold of system time=500 is reached.

         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         enable_response <= 1'b1;
         // Create Objects
         golden_packet = new;
         response_packet = new;
         // Initialize header fields with default values
         golden_packet.init;
         // Overide FlowID
         golden_packet.set_flow_src(SRC0);
         golden_packet.set_flow_dst(DST0);
         // Set packet length to be header plus 5 beats of 2 complex samples
         golden_packet.set_length(beats_to_bytes(2+5));
         // Set timestamp of first packet to be 1000...
         golden_packet.set_timestamp(1000);
         // Explict set packet type to INT16_COMPLEX
         golden_packet.set_packet_type(INT16_COMPLEX);
         for (integer i = 0; i < 10; i++) begin
            $display("Response Packet %d",i);
            // Initialize ramp waveform start value to zero on first pass
            golden_packet.ramp(i===0);
            if (i === 9) begin
               // End of Burst Reached.
               golden_packet.set_packet_type(INT16_COMPLEX_EOB);
            end
            axis_response_post.pop_pkt(response_packet);
            get_header_time(bytes_to_beats(golden_packet.get_length),response_time);
            `FAIL_UNLESS(response_time === (golden_packet.get_timestamp()+3-500));
            // (void cast warning)
            `FAIL_UNLESS(golden_packet.is_same(response_packet,1'b1));
            // Increment Sequence Number
            golden_packet.inc_seq_id;
            // Increment Packet Time
            golden_packet.set_timestamp(golden_packet.get_timestamp() + 10);
         end // for (integer i = 0; i < 10; i++)

         $display("one_burst_one_clk_per_samp: Good Response");
         disable watchdog_thread;
      end // block: read_response
      //
      // Watchdog kills simulation if any test case fails to decisively PASS or FAIL.
      //
      begin : watchdog_thread
	 timeout = 10000;
	 while(1) begin
	    `FAIL_IF(timeout==0);
	    timeout = timeout - 1;
	    @(negedge clk);
	 end
      end
   join
   `SVTEST_END

     //-------------------------------------------------------------------------------
     // Stream one burst with no throttling.
     //
     // Configured as follows:
     // start_time = 1000
     // packet_size = 10 samples
     // flow_id = {SRC0,DST0}
     // time_per_pkt = 50 (Sample_rate=clk_rate/5)
     // burst_size = 100 (10 packets)
     //
     //-------------------------------------------------------------------------------
   `SVTEST(burst_10pkts_of_10samples_5clkpersamp)
   `INFO("One burst of 10 good packets of INT16_COMPLEX");
   fork
      begin: load_stimulus2
         // Setup this test:
         reset_time <= 1'b1; // Keep system time in reset whilst we setup up stimulus payload.
         csr_enable <= 0;
         csr_time_delta <= 32'd500; // Release 500 clock ticks before scheduled time.
         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Build 100 sample test pattern using ramp
         // Create Objects
         stimulus_packet = new;
         // Initialize header fields with default values
         stimulus_packet.init;
         // Overide FlowID
         stimulus_packet.set_flow_src(SRC0);
         stimulus_packet.set_flow_dst(DST0);
         // Set packet length to be header plus 5 beats of 2 complex samples
         stimulus_packet.set_length(beats_to_bytes(2+5));
         // Set timestamp of first packet to be 1000...
         stimulus_packet.set_timestamp(1000);
         // Explict set packet type to INT16_COMPLEX
         stimulus_packet.set_packet_type(INT16_COMPLEX);
         for (integer i = 0; i < 10; i++) begin
            $display("Stimulus Packet %d",i);
            // Initialize ramp waveform start value to zero on first pass
            stimulus_packet.ramp(i===0);
            if (i === 9) begin
               // End of Burst Reached.
               stimulus_packet.set_packet_type(INT16_COMPLEX_EOB);
            end
            // Push stimulus packet onto stimulus AXIS bus
            axis_stimulus_pre.push_pkt(stimulus_packet);
            // Increment Sequence Number
            stimulus_packet.inc_seq_id;
            // Increment Packet Time
            stimulus_packet.set_timestamp(stimulus_packet.get_timestamp() + 50);
         end // for (integer i = 0; i < 10; i++)
         //
         // Stimulus fully loaded, initialize system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         // Enable configured sub-system operation
         csr_enable <= 1;
         @(negedge clk);
         // Realase system clock to free run
         reset_time <= 1'b0;
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         $display("one_burst_five_clk_per_samp: Stimulus Done");
         //
      end // block: load_stimulus2
      //
      begin: read_response2
         //
         // This simulation should produce 10 packets of 10 samples containing a complex ramp waveform.
         // It should all be a single burst and each sample should increment the clock by one.
         // They should appear on the response bus very shortly after the threshold of system time=500 is reached.

         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         enable_response <= 1'b1;
         // Create Objects
         golden_packet = new;
         response_packet = new;
         // Initialize header fields with default values
         golden_packet.init;
         // Overide FlowID
         golden_packet.set_flow_src(SRC0);
         golden_packet.set_flow_dst(DST0);
         // Set packet length to be header plus 5 beats of 2 complex samples
         golden_packet.set_length(beats_to_bytes(2+5));
         // Set timestamp of first packet to be 1000...
         golden_packet.set_timestamp(1000);
         // Explict set packet type to INT16_COMPLEX
         golden_packet.set_packet_type(INT16_COMPLEX);
         for (integer i = 0; i < 10; i++) begin
            $display("Response Packet %d",i);
            // Initialize ramp waveform start value to zero on first pass
            golden_packet.ramp(i===0);
            if (i === 9) begin
               // End of Burst Reached.
               golden_packet.set_packet_type(INT16_COMPLEX_EOB);
            end
            axis_response_post.pop_pkt(response_packet);
            get_header_time(bytes_to_beats(golden_packet.get_length),response_time);
            `FAIL_UNLESS(response_time === (golden_packet.get_timestamp()+3-500));
            // (void cast warning)
            `FAIL_UNLESS(golden_packet.is_same(response_packet,1'b1));
            // Increment Sequence Number
            golden_packet.inc_seq_id;
            // Increment Packet Time
            golden_packet.set_timestamp(golden_packet.get_timestamp() + 50);
         end // for (integer i = 0; i < 10; i++)

         $display("one_burst_five_clk_per_samp: Good Response");
         disable watchdog_thread;
      end // block: read_response2
      //
      // Watchdog kills simulation if any test case fails to decisively PASS or FAIL.
      //
      begin : watchdog_thread
	 timeout = 10000;
	 while(1) begin
	    `FAIL_IF(timeout==0);
	    timeout = timeout - 1;
	    @(negedge clk);
	 end
      end
   join
   `SVTEST_END
   `SVUNIT_TESTS_END
   //-------------------------------------------------------------------------------
   // Helper tasks to improve code reuse for this specific test bench.
   //-------------------------------------------------------------------------------

   // Task: idle_all()
   // Cause all AXIS buses to go idle.
   task idle_all();
      axis_stimulus_pre.axis.idle_master();
      axis_response_post.axis.idle_slave();
      axis_time.idle_slave();
   endtask // idle_all

   // Pull all the timestamps for a packet form the time FIO but
   // onl only return the one for the header beat.
   task get_header_time;
      input logic [15:0] size;
      output logic [63:0] timestamp;


      logic [63:0]        discard;
      logic               last;

      axis_time.read_beat(timestamp,last);
      for (integer i = 1; i < size; i++) begin
         axis_time.read_beat(discard,last);
      end

   endtask

endmodule // axis_flow_controlled_time_unit_test
