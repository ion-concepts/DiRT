//-------------------------------------------------------------------------------
// File:    axis_stream_to_pkt_backpressured_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Unit tests for axis_stream_to_pkt_backpressured
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`include "svunit_defines.svh"
//`include "drat_protocol.sv"

module axis_stream_to_pkt_backpressured_unit_test;
   import drat_protocol::*;
   import svunit_pkg::svunit_testcase;
   string name = "axis_stream_to_pkt_ut";
   svunit_testcase svunit_ut;

   timeunit 1ns; 
   timeprecision 1ps;

   localparam SIZE_STIM=10;
   localparam SIZE_RESP=11;

   logic  clk;
   logic  rst;

   // Pre-Buffer Input Bus
   axis_t #(.WIDTH(32)) axis_stimulus_pre(.clk(clk));
   // Bus between stimulus buffer and valve
   axis_t #(.WIDTH(32)) axis_stimulus_post(.clk(clk));
   // Bus between stimulus valve and UUT
   axis_t #(.WIDTH(32)) axis_stimulus_gated(.clk(clk));
   
   // DUT Output bus
   pkt_stream_t axis_response_gated(.clk(clk));
   // Bus between response vavle and buffer
   pkt_stream_t axis_response_pre(.clk(clk));
   // Post Buffer Output bus
   pkt_stream_t axis_response_post(.clk(clk));

   
   logic  enable;
   // Write this register with start time to annotate into bursts first packet.
   logic [63:0] start_time;
   // Packet size expressed in number of samples
   logic [13:0] packet_size;
   // DRaT Flow ID for this flow (union of src + dst)
   logic [31:0] flow_id; 
   // Time increment per packet of size packet_size
   logic [15:0] time_per_pkt;
   // Number of samples in a burst. Write to zero for infinite burst.
   logic [47:0] burst_size;
   // Assert this signal for a single cycle to trigger an async return to idle.
   logic        abort;

   // Declarations for Stimulus Thread(s)
   logic        enable_stimulus;
   logic        enable_response;
   logic        ready_to_test;
   // Declarations for Response Thread(s)
   DRaTPacket golden_packet, response_packet;
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
   

   //-------------------------------------------------------------------------------
   // Buffer input sample stream 
   // FIFO is 32 bits wide for one complex 16b sample per clock.
   //-------------------------------------------------------------------------------
   // Unused FIFO ports
   wire [SIZE_STIM:0] space_stim, occupied_stim;

   axis_fifo_wrapper  #(
                        .SIZE(SIZE_STIM)
                        )
   axis_fifo_stimulus_i (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_stimulus_pre),
                         .out_axis(axis_stimulus_post),
                         //-- Current fullness of FIFO
                         .space(space_stim),
                         .occupied(occupied_stim)
                         );

   

   axis_valve axis_valve_stimulus_i (
                                     .clk(clk),
                                     .rst(rst),
                                     .in_axis(axis_stimulus_post),
                                     .out_axis(axis_stimulus_gated),
                                     .enable(enable_stimulus)
                                     );
   
   //===================================
   // This is the UUT that we're 
   // running the Unit Tests on
   //===================================

   axis_stream_to_pkt_backpressured
     #(
       .TIME_FIFO_SIZE(4),
       .SAMPLE_FIFO_SIZE(13),
       .PACKET_FIFO_SIZE(8),
       .IQ_WIDTH(16)
       )
   my_axis_stream_to_pkt_backpressured
     (
      .clk(clk),
      .rst(rst),
      //-------------------------------------------------------------------------------
      // CSR registers
      //-------------------------------------------------------------------------------
      .enable(enable),
      .start_time(start_time),
      .packet_size(packet_size), // Packet size expressed in 64bit words including headers
      .flow_id(flow_id), // DRaT Flow ID for this flow (union of src + dst)
      .time_per_pkt(time_per_pkt),
      .burst_size(burst_size),
      .abort(abort),
      // Status Flags
      .idle(idle),
      //-------------------------------------------------------------------------------
      // Streaming sample Input Bus
      //-------------------------------------------------------------------------------
      .axis_stream(axis_stimulus_gated),
      //-------------------------------------------------------------------------------
      // AXIS Output Bus
      //-------------------------------------------------------------------------------
      .axis_pkt_out(axis_response_gated.axis)
      );

   //-------------------------------------------------------------------------------
   // Buffer output response sample stream 
   //-------------------------------------------------------------------------------
   axis_valve axis_valve_response_i (
                                     .clk(clk),
                                     .rst(rst),
                                     .in_axis(axis_response_gated.axis),
                                     .out_axis(axis_response_pre.axis),
                                     .enable(enable_response)
                                     );
   // Unused FIFO ports
   wire [SIZE_RESP:0] space_resp,occupied_resp;
   
   axis_fifo_wrapper  #(
                        .SIZE(SIZE_RESP)
                        )
   axis_fifo_response_i (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_response_pre.axis),
                         .out_axis(axis_response_post.axis),
                         //-- Current fullness of FIFO
                         .space(space_resp),
                         .occupied(occupied_resp)
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

      rst <= 1'b1;
      enable <= 0;
      start_time <= 0; // Write this register with start time to annotate into bursts first packet.
      packet_size <= 0; // Packet size expressed in number of samples
      flow_id <= 0; // DRaT Flow ID for this flow (union of src + dst)
      time_per_pkt <= 0; // Time increment per packet of size packet_size
      burst_size <= 0; // Number of samples in a burst. Write to zero for infinite burst.
      abort <= 0; // Assert this signal for a single cycle to trigger an async return to idle.
      
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
     // Simple Test. Stream one burst with no throttling.
     //
     // Configured as follows:
     // start_time = 1000
     // packet_size = 10 samples
     // flow_id = {INPUT,OUTPUT}
     // time_per_pkt = 10 (Sample_rate=clk_rate)
     // burst_size = 100 (10 packets)
     //
     //-------------------------------------------------------------------------------
     `SVTEST(burst_10pkts_of_10samples)
   `INFO("One burst of 10 good packets of INT16_COMPLEX");
   fork
      begin: load_stimulus
         // Setup this test:                   
         enable <= 0;
         start_time <= 'd1000; 
         packet_size <= 'd10; 
         flow_id <= {INPUT,OUTPUT}; 
         time_per_pkt <= 10;
         burst_size <= 100;
         abort <= 0;
         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Build 100 sample test pattern using ramp
         for (logic [15:0] i = 0; i < 200; i=i+2 ) begin
            axis_stimulus_pre.write_beat({i,i+16'd1},1'b0);
         end


         //
         // Stimulus fully loaded, initialize system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         // Enable configured sub-system operation
         enable <= 1;
         @(negedge clk);
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
         //
         
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);

         // Create Objects
         golden_packet = new;
         response_packet = new;
         // Initialize header fields with default values
         golden_packet.init;
         // Overide FlowID
         golden_packet.set_flow_src(INPUT);
         golden_packet.set_flow_dst(OUTPUT);
         // Set packet length to be header plus 5 beats of 2 complex samples
         golden_packet.set_length(beats_to_bytes(2+5));
         // Set timestamp of first packet to be 1000...
         golden_packet.set_timestamp(1000);
         // Explict set packet type to INT16_COMPLEX
         golden_packet.set_packet_type(INT16_COMPLEX);
         for (integer i = 0; i < 10; i++) begin
            $display("Packet %d",i);
            // Initialize ramp waveform start value to zero on first pass
            golden_packet.ramp(i===0);
            if (i === 9) begin
               // End of Burst Reached.
               golden_packet.set_packet_type(INT16_COMPLEX_EOB);
            end                      
            axis_response_post.pop_pkt(response_packet);
            // (Assert stops implicit void cast warning)
            `FAIL_UNLESS(golden_packet.is_same(response_packet,1'b0));
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


     `SVUNIT_TESTS_END

       //-------------------------------------------------------------------------------
       // Helper tasks to improve code reuse for this specific test bench.
       //-------------------------------------------------------------------------------

       // Task: idle_all()
       // Cause all AXIS buses to go idle.
       task idle_all();
          axis_stimulus_pre.idle_master();
          axis_response_post.axis.idle_slave();
       endtask // idle_all



endmodule
