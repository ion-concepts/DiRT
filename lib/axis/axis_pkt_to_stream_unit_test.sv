//-----------------------------------------------------------------------------
// File:    axis_pkt_to_stream_unit_test.sv
//
// Description:
// Unit tests for fully integrated axis_pkt_to_stream subsystem.
// All directly DUT interfacing buses are src/sunk into axis_fifo style
// RTL so that the local signalling has application style timing and behavior.
// Behavioral test benches interface to the other sides of the FIFOs.
//
// Response checking works on the principle that you can forward the input packet payloads to
// the response checker directly, and providing the response checker can identify
// bus cycles where error state handling has been invoked, and digital silence (0+0j) samples
// are correctly placed on the bus to conceal cycles during error handling, then
// it is self checking for all conditions.
//
// Status checking is very manual and must be explicitly crafted for any simulation that
// tests error handling since the error recovery process is influenced extensively
// by the timing of stimulus.
//
// Consumption Checking is more straight forward but still needs to be hand crafted for some
// error recovery scenarios.
//
// This bench currently only tests configurations and scenarios deemed likely for it's initial
// use case(s). For example "Next burst policy" for error recovery is not used in the bench.
//-----------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "axis_pkt_to_stream.sv"

module axis_pkt_to_stream_unit_test;
   timeunit 1ns;
   timeprecision 1ps;

   import drat_protocol::*;
   import axis_pkt_to_stream_pkg::*;
   import svunit_pkg::svunit_testcase;

   string name = "axis_pkt_to_stream_ut";
   svunit_testcase svunit_ut;


   logic  clk;
   logic  rst;
   // Watchdog
   int timeout;
   
   // Time
   logic [63:0] current_time;

   // DUT Signals (non AXIS)
   logic [31:0] status_flow_id;
   logic [31:0] consumption_flow_id;
   logic        error_policy_next_packet;
   //logic        run;
   logic        deframer_enable;
   logic        status_enable;
   logic        consumption_enable;
   logic        tx_control_enable;


   // Declarations for Stimulus Thread(s)
   DRaTPacket test_packet;
   int          x,y;
   int          clks_per_sample;
   logic [63:0] beat_in;
   logic [63:0] beat1, beat2;
   logic        status_tlast;
   logic        enable_stimulus;
   logic        enable_response;
   logic [63:0] time_this_sample;
   logic        ready_to_test;
   logic        discard_enable;
   logic [63:0] demux_header;
   logic [1:0]  demux_select;

   // Declarations for Status threads
   DRaTPacket status_packet;
   // Declarations for Consumption threads
   DRaTPacket consumption_packet;
   // Declarations for Response Thread(s)
   logic [95:0] golden_beat, response_beat;
   logic        golden_tlast, response_tlast;
   logic [63:0] golden_timestamp, response_timestamp;
   int          response_pkt_count;



   // Pre-Buffer Input Bus
   pkt_stream_t axis_stimulus_pre(.clk(clk));
   // Bus between stimulus buffer and demux4
   pkt_stream_t axis_stimulus_post(.clk(clk));
   // Bus betweeen demux4 and valve
   pkt_stream_t axis_stimulus_demux(.clk(clk));
   // DUT Input bus
   pkt_stream_t axis_stimulus_gated(.clk(clk));
   // DUT Status Bus
   pkt_stream_t axis_status_pre(.clk(clk));
   // Post Buffer Status Bus
   pkt_stream_t axis_status_post(.clk(clk));
   // DUT Consumption Bus
   pkt_stream_t axis_consumption_pre(.clk(clk));
   // Post Buffer Consumption Bus
   pkt_stream_t axis_consumption_post(.clk(clk));
   // DUT Output bus
   axis_t #(.WIDTH(32)) axis_response_gated(.clk(clk));
   // Bus between response vavale and buffer with Time concatenated.
   axis_t #(.WIDTH(96)) axis_response_pre(.clk(clk));
   // Post Buffer Output bus with Time concatenated.
   axis_t #(.WIDTH(96)) axis_response_post(.clk(clk));
   // Raw sample Golden Data
   axis_t #(.WIDTH(96)) axis_golden_pre(.clk(clk)), axis_golden_post(.clk(clk));

   // Discard buses on demux4
   axis_t #(.WIDTH(64)) axis_out1_demux(.clk(clk)), axis_out2_demux(.clk(clk)), axis_out3_demux(.clk(clk));

   //
   // Generate clk. (Nominally 100MHz, but that is arbitrary.)
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
	current_time <= 0;
      else
	current_time <= current_time + 1 ;
   end


   //----------------------------------
   // This is the UUT that we're
   // running the Unit Tests on
   //----------------------------------

   axis_pkt_to_stream axis_pkt_to_stream_i0
     (
      .clk(clk),
      .rst(rst),
      // enable pins
      .deframer_enable(deframer_enable),
      .status_enable(status_enable),
      .consumption_enable(consumption_enable),
      .tx_control_enable(tx_control_enable),
      // System time in
      .current_time(current_time),
      // FlowID to me used in status packet header
      .status_flow_id(status_flow_id),
      // FlowID to me used in consumption packet header
      .consumption_flow_id(consumption_flow_id),
      // Error policy register
      .error_policy_next_packet(error_policy_next_packet),
      // Flag Output beats that are active sample data vs zero padding
      .run_out(),
      // Dirt/DRat packetized stream in
      .axis_pkt(axis_stimulus_gated.axis),
      // Status pkt stream out
      .axis_status(axis_status_pre.axis),
      // Consumption pkt stream out
      .axis_consumption(axis_consumption_pre.axis),
      // Stream oriented raw IQ samples out
      .axis_stream(axis_response_gated)
      );

    //-------------------------------------------------------------------------------
    // Buffer input stimulus packet stream.
    // Pass first to a FIFO to buffer test stimulus.
    // Then a DEMUX to allow packets to be selectively discarded to simulate packet loss.
    // Then finally a valve so that the buffer can be loaded, then bursted,
    // at full rate, or be modulated to reduce the rate.
    //-------------------------------------------------------------------------------

    axis_fifo_wrapper  #(
                         .SIZE(10)
                         )
    axis_fifo_stimulus_i (
                          .clk(clk),
                          .rst(rst),
                          .in_axis(axis_stimulus_pre.axis),
                          .out_axis(axis_stimulus_post.axis)
                          );

    axis_demux4_wrapper #(
                          .WIDTH(64)
                          )
    axis_demux4_stimulus_i (
                            .clk(clk),
                            .rst(rst),
                            .header_out(demux_header),
                            .select_in(demux_select),
                            .out0_axis(axis_stimulus_demux.axis),
                            .out1_axis(axis_out1_demux),
                            .out2_axis(axis_out2_demux),
                            .out3_axis(axis_out3_demux),
                            .in_axis(axis_stimulus_post.axis)
                            );


    always_comb begin
        // Discard all traffic that egresses on these ports
        axis_out1_demux.tready = 1'b1;
        axis_out2_demux.tready = 1'b1;
        axis_out3_demux.tready = 1'b1;
        // Discard any packet with Seq Num == 2 if enabled
        // (This simulates packet loss)
        if ((demux_header[55:48] === 8'd2) && discard_enable) begin
            demux_select = 2'd1;
        end else begin
            demux_select = 2'd0;
        end
    end


    axis_valve axis_valve_stimulus_i (
                                      .clk(clk),
                                      .rst(rst),
                                      .in_axis(axis_stimulus_demux.axis),
                                      .out_axis(axis_stimulus_gated.axis),
                                      .enable(enable_stimulus)
                                      );


    //-------------------------------------------------------------------------------
    // Buffer ouput status response packet stream
    //-------------------------------------------------------------------------------

    axis_fifo_wrapper  #(
                         .SIZE(8)
                         )
    axis_fifo_status_i (
                        .clk(clk),
                        .rst(rst),
                        .in_axis(axis_status_pre.axis),
                        .out_axis(axis_status_post.axis)
                        );

    //-------------------------------------------------------------------------------
    // Buffer ouput consumption response packet stream
    //-------------------------------------------------------------------------------

    axis_fifo_wrapper  #(
                         .SIZE(8)
                         )
    axis_fifo_consumption_i (
                             .clk(clk),
                             .rst(rst),
                             .in_axis(axis_consumption_pre.axis),
                             .out_axis(axis_consumption_post.axis)
                             );

    //-------------------------------------------------------------------------------
    // Buffer output response sample stream with dispatch time metadata
    //-------------------------------------------------------------------------------
    axis_concat_data #(.WIDTH(64))
    axis_valve_response_i (
                           .clk(clk),
                           .rst(rst),
                           .in_axis(axis_response_gated),
                           .concat_data_in(current_time),
                           .out_axis(axis_response_pre),
                           .enable(enable_response)
                           );

    axis_fifo_wrapper  #(
                         .SIZE(11)
                         )
    axis_fifo_response_i (
                          .clk(clk),
                          .rst(rst),
                          .in_axis(axis_response_pre),
                          .out_axis(axis_response_post)
                          );

    //-------------------------------------------------------------------------------
    // Buffer golden response sample stream with dispatch time metadata
    //-------------------------------------------------------------------------------

    axis_fifo_wrapper  #(
                         .SIZE(11)
                         )
    axis_fifo_wrapper_i (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_golden_pre),
                         .out_axis(axis_golden_post)
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
      status_flow_id <= {DST0,SRC0};
      consumption_flow_id <= {DST0,SRC0};
      ready_to_test <= 0;
      clks_per_sample <= 0;
      discard_enable <= 0;
      deframer_enable <= 0;
      status_enable <= 0;
      consumption_enable <= 0;
      tx_control_enable <= 0;

      // Default to Next packet policy
      error_policy_next_packet <= 1;
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
    // One burst of 4 packets of INT16_COMPLEX at full clock/wire rate
    // Sample stream is random I & Q
    //-------------------------------------------------------------------------------
   `SVTEST(one_burst_one_clk_per_samp)
   `INFO("One burst of four good packets back to back of INT16_COMPLEX");
   fork
      begin: load_stimulus
         // Setup this test:
         clks_per_sample <= 1;
         discard_enable <= 0;
         deframer_enable <= 1;
         status_enable <= 1;
         consumption_enable <= 1;
         tx_control_enable <= 1;

         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Setup Packet construction workspace
         initialize_packet_workspace(beats_to_bytes(16),'d1000);
         // Loop over 4 packets
         for (x = 0 ; x < 4 ; x = x + 1) begin
            if (x===3) begin
               populate_packet(INT16_COMPLEX_EOB);
            end else begin
               populate_packet(INT16_COMPLEX);
            end
            // Loop over payload
            for (y = 0 ; y < 15 ; y = y + 1) begin
               push_stimulus_beat(0);
            end
            // Send last beat with TLAST asserted
            push_stimulus_beat(1);
            // Rewind payload pointer again
            test_packet.rewind_payload;
            // Increment Sequence Number
            test_packet.inc_seq_id;
            // Update Timestamp in next packet.
            // 1 Sample per clock on egress and 32 samples per packet.
            test_packet.update_timestamp(32);
         end // for (x = 0 ; x < 4 ; x = x + 1)
         //
         // Stimulus fully loaded, initialise system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         @(negedge clk);
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         `INFO("one_burst_one_clk_per_samp: Stimulus Done");
         //
      end // block: load_stimulus
      //
      begin: read_status
         // This simulation should produce only an EOB ACK status packet.
         //
         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            0,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            EOB_ACK,        // STATUS TYPE
                                            3               // STATUS SEQ NUM
                                            );

         `INFO("one_burst_one_clk_per_samp: Good Status");
      end // block: read_status
      //
      begin: read_consumption
         // This simulation should produce ACK's for 4 consumed packets
         //
         for (int i = 0; i < 4; i++) begin
            consumption_packet = new;
            consumption_packet.copy_to_pkt(axis_consumption_post);
            consumption_packet.assert_status_packet(
                                                    i,              // SEQ NUM
                                                    24,             // LENGTH
                                                    {DST0,SRC0}, // FLOWID
                                                    0,              // TIMESTAMP
                                                    'd1000,         // TIMESTAMP MIN
                                                    'd1135,         // TIMESTAMP MAX
                                                    ACK,            // STATUS TYPE
                                                    i               // STATUS SEQ NUM
                                                    );
         end

         `INFO("one_burst_one_clk_per_samp: Good Consumption");
      end
      //
      begin: read_response
         automatic integer count_resp = 0;
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         // 100% duty cycle on output bus
         enable_response <= 1'b1;
         // While golden not empty
         while (axis_golden_post.tvalid) begin
            // Pop golden response.
            axis_golden_post.read_beat(golden_beat,golden_tlast);
            // Grab golden time stamp.
            golden_timestamp = golden_beat[95:32];
            // Pop response.
            axis_response_post.read_beat(response_beat,response_tlast);
            // Grab reponse time stamp.
            response_timestamp = response_beat[95:32];
            // Compare golden time stamp to response timestamp.
            while (golden_timestamp > response_timestamp) begin
               // assert if response TDATA is not 0
               `FAIL_UNLESS_EQUAL(response_beat[31:0], 32'd0);
               // Pop response.
               axis_response_post.read_beat(response_beat,response_tlast);
               // Grab reponse time stamp.
               response_timestamp = response_beat[95:32];
            end
            // if golden < response then always assert.
            if (golden_timestamp < response_timestamp) assert(0);
            // If golden == response then assert if golden TDATA != response TDATA
            `FAIL_UNLESS_EQUAL(golden_timestamp,response_timestamp);
            `FAIL_UNLESS_EQUAL(golden_beat[31:0],response_beat[31:0]);
            count_resp +=1;
         end // while (axis_golden_post.tvalid)
         `INFO($sformatf("one_burst_one_clk_per_samp: Good Response, checked %d beats.",count_resp));
         disable watchdog_thread;
      end // block: read_response
      //
      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end
   join
   @(negedge clk);
   deframer_enable <= 0;
   status_enable <= 0;
   consumption_enable <= 0;
   tx_control_enable <= 0;

   `SVTEST_END


     //-------------------------------------------------------------------------------
     // One burst of 8 packets of INT16_COMPLEX at full clock/wire rate
     // 4 packets are lost due to underflow and recovery, but stream resyncs.
     // Sample stream is random I & Q
     //-------------------------------------------------------------------------------
   `SVTEST(underflow_one_burst_one_clk_per_samp)
   `INFO("Cause underflow on one burst of eight good packets back to back of INT16_COMPLEX");
   fork
      begin: load_stimulus2
         // Setup this test:
         @(negedge clk);
         clks_per_sample <= 1;
         discard_enable <= 0;
         deframer_enable <= 1;
         status_enable <= 1;
         consumption_enable <= 1;
         tx_control_enable <= 1;

         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Setup Packet construction workspace
         initialize_packet_workspace(beats_to_bytes(16),'d1000);
         // Loop over 8 packets
         for (x = 0 ; x < 8 ; x = x + 1) begin
            if (x===7) begin
               populate_packet(INT16_COMPLEX_EOB);
            end else begin
               populate_packet(INT16_COMPLEX);
            end
            // Loop over payload
            for (y = 0 ; y < 15 ; y = y + 1) begin
               push_stimulus_beat(0);
            end
            // Send last beat with TLAST asserted
            push_stimulus_beat(1);
            // Rewind payload pointer again
            test_packet.rewind_payload;
            // Increment Sequence Number
            test_packet.inc_seq_id;
            // Update Timestamp in next packet.
            // Sample per clock and 32 samples per packet.
            test_packet.update_timestamp(32);
         end // for (x = 0 ; x < 4 ; x = x + 1)
         //
         // Stimulus fully loaded, initialise system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         @(negedge clk);
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         // Count 1 TLAST then block stimulus for long enough that underflow occurs,
         // then reconnect stimulus to see recovery.
         while (!axis_stimulus_gated.axis.tlast) @(posedge clk);
         @(negedge clk);
         enable_stimulus <= 1'b0;
         // Hand crafted delay is important here, other delay values
         // may create a different sequence of error packets.
         for (x = 0 ; x < 650 ; x = x + 1) @(posedge clk);
         enable_stimulus <= 1'b1;
         //
         `INFO("underflow_one_burst_one_clk_per_samp: Stimulus done");
      end // block: load_stimulus
      //
      begin: read_status2
         // This simulation should produce the following status packets in this order:
         // UNDERFLOW
         // LATE
         // LATE
         // LATE
         // EOB ACK
         //

         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            0,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            UNDERFLOW,      // STATUS TYPE
                                            0               // STATUS SEQ NUM
                                            );

         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            1,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            LATE,           // STATUS TYPE
                                            2               // STATUS SEQ NUM
                                            );

         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            2,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            LATE,           // STATUS TYPE
                                            3               // STATUS SEQ NUM
                                            );

         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            3,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            LATE,           // STATUS TYPE
                                            4               // STATUS SEQ NUM
                                            );



         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            4,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1300,         // TIMESTAMP MAX
                                            EOB_ACK,        // STATUS TYPE
                                            7               // STATUS SEQ NUM
                                            );

         `INFO("underflow_one_burst_one_clk_per_samp: Good Status");
      end // block: read_status2
      //
      begin: read_consumption2
         //
         // This simulation should produce ACK's for pkts 0-7 even though some dumped in error state
         //
         for (int i = 0; i < 8; i++) begin
            consumption_packet = new;
            consumption_packet.copy_to_pkt(axis_consumption_post);
            consumption_packet.assert_status_packet(
                                                    i,              // SEQ NUM
                                                    24,             // LENGTH
                                                    {DST0,SRC0}, // FLOWID
                                                    0,              // TIMESTAMP
                                                    'd1000,         // TIMESTAMP MIN
                                                    'd1400,         // TIMESTAMP MAX
                                                    ACK,            // STATUS TYPE
                                                    i               // STATUS SEQ NUM
                                                    );
         end

         `INFO("underflow_one_burst_one_clk_per_samp: Good Consumption");
      end
      //
      begin: read_response2
         automatic integer count_resp = 0;
         // This test case causes underflow and the subsequent loss
         // of Packets with Sequence numbers 1,2,3,4 before the
         // axis_pkt_to_stream module is able to resynchronize
         // and continue operation. Thus golden response data
         // for the 2nd,3rd,& 4th packets must be purged,
         // as there is no equivalent response data to compare against.
         //
         response_pkt_count <= 0;
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         // 100% duty cycle on output bus
         enable_response <= 1'b1;
         // While golden not empty
         while (axis_golden_post.tvalid) begin
            // Pop golden response.
            axis_golden_post.read_beat(golden_beat,golden_tlast);
            // Grab golden time stamp.
            golden_timestamp = golden_beat[95:32];
            // Check for asserted tlast and increment calculated Seq Num if so.
            // (Note: non-blocking increment needed for following code block)
            if (axis_golden_post.tlast === 1) begin
               response_pkt_count <= response_pkt_count + 1;
            end
            // Continue without checking response if we are reading packets with seq nums 1|2|3|4
            // We are discarding Golden packets here that were lost as a result of the underflow.
            if ((response_pkt_count > 0) && (response_pkt_count < 5)) begin
               continue;
            end
            // Pop response.
            axis_response_post.read_beat(response_beat,response_tlast);
            // Grab reponse time stamp.
            response_timestamp = response_beat[95:32];
            // Compare golden time stamp to response timestamp.
            // Drain zero valued fill samples until timestamps match.
 
            while (golden_timestamp > response_timestamp) begin
               $display("Golden time: %d  Response Time: %d @ time: %d",golden_timestamp , response_timestamp, $time);
               $display("Response Beat: %x",  response_beat[31:0]);
               
               // assert if response TDATA is not 0
               // IJB Removed this assert because the initial beats of the underflowing packet can get into the response
               //`FAIL_UNLESS_EQUAL(response_beat[31:0],32'd0);
               // Pop response.
               axis_response_post.read_beat(response_beat,response_tlast);
               // Grab reponse time stamp.
               response_timestamp = response_beat[95:32];
            end // while (golden_timestamp > response_timestamp)
            $display("timestamps match: %d",golden_timestamp);
            
            // if golden < response then always assert.
            if (golden_timestamp < response_timestamp) assert(0);
            // If golden == response then assert if golden TDATA != response TDATA
            `FAIL_UNLESS_EQUAL(golden_timestamp,response_timestamp);
            `FAIL_UNLESS_EQUAL(golden_beat[31:0],response_beat[31:0]);
            count_resp+=1;
         end // while (axis_golden_post.tvalid)
         `INFO($sformatf("underflow_one_burst_one_clk_per_samp: Good Response, checked %d beats.", count_resp));
         disable watchdog_thread;
      end // block: read_response
      //
      
      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end
   join
   @(negedge clk);
   deframer_enable <= 0;
   status_enable <= 0;
   consumption_enable <= 0;
   tx_control_enable <= 0;

   `SVTEST_END


     //-------------------------------------------------------------------------------
     // One burst of 8 packets of INT16_COMPLEX at full clock/wire rate
     // 1 packets is lost in transport causing bad seq num, but stream resyncs.
     // Sample stream is random I & Q
     //-------------------------------------------------------------------------------
   `SVTEST(lost_pkt_one_burst_one_clk_per_samp)
   `INFO("Cause lost packet on one burst of eight good packets back to back of INT16_COMPLEX");
   fork
      begin: load_stimulus3
         // Setup this test:
         @(negedge clk);
         clks_per_sample <= 1;
         discard_enable <= 1;
         deframer_enable <= 1;
         status_enable <= 1;
         consumption_enable <= 1;
         tx_control_enable <= 1;

         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Setup Packet construction workspace
         initialize_packet_workspace(beats_to_bytes(16),'d1000);
         // Loop over 8 packets
         for (x = 0 ; x < 8 ; x = x + 1) begin
            if (x===7) begin
               populate_packet(INT16_COMPLEX_EOB);
            end else begin
               populate_packet(INT16_COMPLEX);
            end
            // Loop over payload
            for (y = 0 ; y < 15 ; y = y + 1) begin
               push_stimulus_beat(0);
            end
            // Send last beat with TLAST asserted
            push_stimulus_beat(1);
            // Rewind payload pointer again
            test_packet.rewind_payload;
            // Increment Sequence Number
            test_packet.inc_seq_id;
            // Update Timestamp in next packet.
            // Sample per clock and 32 samples per packet.
            test_packet.update_timestamp(32);
         end // for (x = 0 ; x < 4 ; x = x + 1)
         //
         // Stimulus fully loaded, initialise system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         @(negedge clk);
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         `INFO("lost_pkt_one_burst_one_clk_per_samp: Stimulus done");
      end // block: load_stimulus
      //
      begin: read_status3
         //
         // This simulation should produce a SEQ_ERR_MID followed by EOB ACK status packet.
         //
         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            0,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            SEQ_ERROR_MID,  // STATUS TYPE
                                            3               // STATUS SEQ NUM
                                            );

         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            1,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1300,         // TIMESTAMP MAX
                                            EOB_ACK,        // STATUS TYPE
                                            7               // STATUS SEQ NUM
                                            );


         `INFO("lost_pkt_one_burst_one_clk_per_samp: Good Status");
      end // block: read_status3
      //
      begin: read_consumption3
         //
         // This simulation should produce ACK's for pkts [0,1,3-7] even though some discarded in error state.
         // Seq Num 2 is lost in transport and is never presented to the DUT.
         // Packets after lost packet have delta of 1 between there own Seq Num and teh Status Seq Num.
         //
         for (int i = 0; i < 2; i++) begin
            consumption_packet = new;
            consumption_packet.copy_to_pkt(axis_consumption_post);
            consumption_packet.assert_status_packet(
                                                    i,              // SEQ NUM
                                                    24,             // LENGTH
                                                    {DST0,SRC0}, // FLOWID
                                                    0,              // TIMESTAMP
                                                    'd1000,         // TIMESTAMP MIN
                                                    'd1400,         // TIMESTAMP MAX
                                                    ACK,            // STATUS TYPE
                                                    i               // STATUS SEQ NUM
                                                    );
         end

         for (int i = 2; i < 7; i++) begin
            consumption_packet = new;
            consumption_packet.copy_to_pkt(axis_consumption_post);
            consumption_packet.assert_status_packet(
                                                    i,              // SEQ NUM
                                                    24,             // LENGTH
                                                    {DST0,SRC0}, // FLOWID
                                                    0,              // TIMESTAMP
                                                    'd1000,         // TIMESTAMP MIN
                                                    'd1400,         // TIMESTAMP MAX
                                                    ACK,            // STATUS TYPE
                                                    i+1               // STATUS SEQ NUM
                                                    );
         end

         `INFO("lost_pkt_one_burst_one_clk_per_samp: Good Consumption");
      end
      //
      //
      begin: read_response3
         automatic integer count_resp = 0;
         // This test case causes the loss
         // of Packets with Sequence number 2 before the
         // axis_pkt_to_stream module is able to resynchronize
         // and continue operation. Thus golden response data
         // for the 3rd packet must be purged,
         // as there is no equivalent response data to compare against.
         //
         response_pkt_count <= 0;
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         // 100% duty cycle on output bus
         enable_response <= 1'b1;
         // While golden not empty
         while (axis_golden_post.tvalid) begin
            // Pop golden response.
            axis_golden_post.read_beat(golden_beat,golden_tlast);
            // Grab golden time stamp.
            golden_timestamp = golden_beat[95:32];
            // Check for asserted tlast and increment calculated Seq Num if so.
            // (Note: non-blocking increment needed for following code block)
            if (axis_golden_post.tlast === 1) begin
               response_pkt_count <= response_pkt_count + 1;
            end
            // Break if we are reading packets with seq num 2
            if ((response_pkt_count > 1) && (response_pkt_count < 3)) begin
               continue;
            end
            // Pop response.
            axis_response_post.read_beat(response_beat,response_tlast);
            // Grab reponse time stamp.
            response_timestamp = response_beat[95:32];
            // Compare golden time stamp to response timestamp.
            while (golden_timestamp > response_timestamp) begin
               // assert if response TDATA is not 0
               `FAIL_UNLESS_EQUAL(response_beat[31:0], 32'd0);
               // Pop response.
               axis_response_post.read_beat(response_beat,response_tlast);
               // Grab reponse time stamp.
               response_timestamp = response_beat[95:32];
            end
            // if golden < response then always assert.
            if (golden_timestamp < response_timestamp) assert(0);
            // If golden == response then assert if golden TDATA != response TDATA
            `FAIL_UNLESS_EQUAL(golden_timestamp,response_timestamp);
            `FAIL_UNLESS_EQUAL(golden_beat[31:0],response_beat[31:0]);
            count_resp += 1;
         end // while (axis_golden_post.tvalid)
         `INFO($sformatf("lost_pkt_one_burst_one_clk_per_samp: Good Response, checked %d beats", count_resp));

      end // block: read_response
      //
      
      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end

   join
   @(negedge clk);
   deframer_enable <= 0;
   status_enable <= 0;
   consumption_enable <= 0;
   tx_control_enable <= 0;
   `SVTEST_END


     //-------------------------------------------------------------------------------
     // One burst of 4 packets of INT16_COMPLEX at 1/4 clock/wire rate
     // Sample stream is random I & Q
     //-------------------------------------------------------------------------------
   `SVTEST(one_burst_four_clks_per_samp)
   `INFO("One burst of four good packets back to back of INT16_COMPLEX at 1/4 clk");
   fork
      begin: load_stimulus4
         // Setup this test:
         clks_per_sample <= 4;
         discard_enable <= 0;
         deframer_enable <= 1;
         status_enable <= 1;
         consumption_enable <= 1;
         tx_control_enable <= 1;

         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Setup Packet construction workspace
         initialize_packet_workspace(beats_to_bytes(16),'d1000);
         // Loop over 4 packets
         for (x = 0 ; x < 4 ; x = x + 1) begin
            if (x===3) begin
               populate_packet(INT16_COMPLEX_EOB);
            end else begin
               populate_packet(INT16_COMPLEX);
            end
            // Loop over payload
            for (y = 0 ; y < 15 ; y = y + 1) begin
               push_stimulus_beat(0);
            end
            // Send last beat with TLAST asserted
            push_stimulus_beat(1);
            // Rewind payload pointer again
            test_packet.rewind_payload;
            // Increment Sequence Number
            test_packet.inc_seq_id;
            // Update Timestamp in next packet.
            // Sample every 4th clock and 32 samples per packet.
            test_packet.update_timestamp(128);
         end // for (x = 0 ; x < 4 ; x = x + 1)
         //
         // Stimulus fully loaded, initialise system for test and release stimulus
         // by opening valve.
         //
         @(posedge clk);
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         // Fudge alignment of modulation of egress pipeline
         // So that golden timestamps align with response timestamps.
         // Not important in the real world, but needed here for test bench
         // to be rigorous.
         // Timestamp of stream start is 'd1000 so line up asserted cycle
         // of TREADY
         while (1) begin
            @(posedge clk);
            if (current_time % 4 == 0) begin
               enable_response <= 1'b1;
            end else begin
               enable_response <= 1'b0;
            end
            if (current_time > 2000) begin
               // Well past end of test
               break;
            end
         end
         `INFO("one_burst_four_clks_per_samp: Stimulus Done");
         //
      end // block: load_stimulus
      //
      begin: read_status4
         //
         // This simulation should produce only an EOB ACK status packet.
         //
         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            0,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd1000,         // TIMESTAMP MIN
                                            'd1600,         // TIMESTAMP MAX
                                            EOB_ACK,        // STATUS TYPE
                                            3               // STATUS SEQ NUM
                                            );

         `INFO("one_burst_four_clks_per_samp: Good Status");
      end // block: read_status4
      //
      begin: read_consumption4
         //
         // This simulation should produce ACK's for pkts 0-3
         //
         for (int i = 0; i < 4; i++) begin
            consumption_packet = new;
            consumption_packet.copy_to_pkt(axis_consumption_post);
            consumption_packet.assert_status_packet(
                                                    i,              // SEQ NUM
                                                    24,             // LENGTH
                                                    {DST0,SRC0}, // FLOWID
                                                    0,              // TIMESTAMP
                                                    'd1000,         // TIMESTAMP MIN
                                                    'd1600,         // TIMESTAMP MAX
                                                    ACK,            // STATUS TYPE
                                                    i               // STATUS SEQ NUM
                                                    );
         end

         `INFO("one_burst_four_clks_per_samp: Good Consumption");
      end
      //
      //
      begin: read_response4
         automatic integer count_resp = 0;
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);

         // While golden not empty
         while (axis_golden_post.tvalid) begin
            // Pop golden response.
            axis_golden_post.read_beat(golden_beat,golden_tlast);
            // Grab golden time stamp.
            golden_timestamp = golden_beat[95:32];
            // Pop response.
            axis_response_post.read_beat(response_beat,response_tlast);
            // Grab reponse time stamp.
            response_timestamp = response_beat[95:32];
            // Compare golden time stamp to response timestamp.
            while (golden_timestamp > response_timestamp) begin
               // assert if response TDATA is not 0
               `FAIL_UNLESS_EQUAL(response_beat[31:0], 32'd0);
               // Pop response.
               axis_response_post.read_beat(response_beat,response_tlast);
               // Grab reponse time stamp.
               response_timestamp = response_beat[95:32];
            end
            // if golden < response then always assert.
            if (golden_timestamp < response_timestamp) assert(0);
            // If golden == response then assert if golden TDATA != response TDATA
            `FAIL_UNLESS_EQUAL(golden_timestamp,response_timestamp);
            `FAIL_UNLESS_EQUAL(golden_beat[31:0],response_beat[31:0]);
            count_resp += 1;
         end // while (axis_golden_post.tvalid)
         `INFO($sformatf("one_burst_four_clks_per_samp: Good Response, checked %d beats", count_resp));
         disable watchdog_thread;
      end // block: read_response
      //
      
      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end
      
   join
   @(negedge clk);
   deframer_enable <= 0;
   status_enable <= 0;
   consumption_enable <= 0;
   tx_control_enable <= 0;

   `SVTEST_END

     //-------------------------------------------------------------------------------
     // One burst of 4 packets of INT16_COMPLEX_ASYNC at 1/7 clock/wire rate
     // Sample stream is random I & Q
     //-------------------------------------------------------------------------------
   `SVTEST(async_one_burst_seven_clks_per_samp)
   `INFO("One burst of four good packets back to back of INT16_COMPLEX_ASYNC at 1/7 clk");
   fork
      begin: load_stimulus5
         // Setup this test:
         clks_per_sample <= 7;
         discard_enable <= 0;
         deframer_enable <= 1;
         status_enable <= 1;
         consumption_enable <= 1;
         tx_control_enable <= 1;

         // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
         // Setup Packet construction workspace
         initialize_packet_workspace(beats_to_bytes(16),'d1000);
         // Loop over 4 packets
         for (x = 0 ; x < 4 ; x = x + 1) begin
            if (x===3) begin
               populate_packet(INT16_COMPLEX_ASYNC_EOB);
            end else begin
               populate_packet(INT16_COMPLEX_ASYNC);
            end
            // Loop over payload
            for (y = 0 ; y < 15 ; y = y + 1) begin
               push_stimulus_beat(0);
            end
            // Send last beat with TLAST asserted
            push_stimulus_beat(1);
            // Rewind payload pointer again
            test_packet.rewind_payload;
            // Increment Sequence Number
            test_packet.inc_seq_id;
            // Update Timestamp in next packet.
            // Sample every 7th clock and 32 samples per packet.
            test_packet.update_timestamp(224);
         end // for (x = 0 ; x < 4 ; x = x + 1)
         //
         // Stimulus fully loaded, initialise system for test and release stimulus
         // by opening valve.
         //
         @(posedge clk);
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         // Fudge alignment of modulation of egress pipeline
         // So that golden timestamps align with response timestamps.
         // Not important in the real world, but needed here for test bench
         // to be rigorous.
         // Timestamp of stream start is 'd1000 so line up asserted cycle
         // of TREADY
         while (1) begin
            @(posedge clk);
            if (current_time % 7 == 0) begin
               enable_response <= 1'b1;
            end else begin
               enable_response <= 1'b0;
            end
            if (current_time > 2000) begin
               // Well past end of test
               break;
            end
         end
         `INFO("async_one_burst_seven_clks_per_samp: Stimulus Done");
         //
      end // block: load_stimulus
      //
      begin: read_status5
         //
         // This simulation should produce only an EOB ACK status packet.
         //
         status_packet = new;
         status_packet.copy_to_pkt(axis_status_post);
         status_packet.assert_status_packet(
                                            0,              // SEQ NUM
                                            24,             // LENGTH
                                            {DST0,SRC0}, // FLOWID
                                            0,              // TIMESTAMP
                                            'd400,         // TIMESTAMP MIN
                                            'd1200,         // TIMESTAMP MAX
                                            EOB_ACK,        // STATUS TYPE
                                            3               // STATUS SEQ NUM
                                            );

         `INFO("async_one_burst_seven_clks_per_samp: Good Status");
      end // block: read_status4
      //
      begin: read_consumption5
         //
         // This simulation should produce ACK's for pkts 0-3
         //
         for (int i = 0; i < 4; i++) begin
            consumption_packet = new;
            consumption_packet.copy_to_pkt(axis_consumption_post);
            consumption_packet.assert_status_packet(
                                                    i,              // SEQ NUM
                                                    24,             // LENGTH
                                                    {DST0,SRC0}, // FLOWID
                                                    0,              // TIMESTAMP
                                                    'd400,         // TIMESTAMP MIN
                                                    'd1200,         // TIMESTAMP MAX
                                                    ACK,            // STATUS TYPE
                                                    i               // STATUS SEQ NUM
                                                    );
         end

         `INFO("async_one_burst_seven_clks_per_samp: Good Consumption");
      end
      //
      // Response check for ASYNC types is less precise because it's best effort transport,
      // the exact time that samples are trasnfered onto the egress is not a PASS/FAIL criteria,
      // only that they are the correct values
      //
      begin: read_response5
         automatic integer count_resp = 0;
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);

         // While golden not empty
         while (axis_golden_post.tvalid) begin
            // Pop golden response.
            axis_golden_post.read_beat(golden_beat,golden_tlast);
            // Pop response.
            axis_response_post.read_beat(response_beat,response_tlast);
            // Discard any digital silence
            // (This is a little bit bold since we can't check
            // golden response timestamp like in the SYNC case,
            // But we know that zero valued samples are not valid
            // responses for this test case)
            while (response_beat[31:0] === 32'd0) begin
               // Pop response.
               axis_response_post.read_beat(response_beat,response_tlast);
            end
            `FAIL_UNLESS_EQUAL(golden_beat[31:0],response_beat[31:0]);
            count_resp += 1;

         end // while (axis_golden_post.tvalid)
         `INFO($sformatf("async_one_burst_seven_clks_per_samp: Good Response, checked %d beats", count_resp));
         disable watchdog_thread;
      end // block: read_response

      //
      begin : watchdog_thread
         timeout = 100000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end
   join
   @(negedge clk);
   deframer_enable <= 0;
   status_enable <= 0;
   consumption_enable <= 0;
   tx_control_enable <= 0;

   `SVTEST_END
 `SVUNIT_TESTS_END



//-------------------------------------------------------------------------------
// Helper tasks to improve code reuse for this specific test bench.
//-------------------------------------------------------------------------------

// Task: idle_all()
// Cause all AXIS buses to go idle.
task idle_all();
   axis_stimulus_pre.axis.idle_master();
   axis_status_post.axis.idle_slave();
   axis_consumption_post.axis.idle_slave();
   axis_response_post.idle_slave();
   axis_golden_post.idle_slave();
endtask // idle_all

// Push one beat of a packet from the work space to both stimulus
// and golden response FIFO's and also update time_this_sample.
task push_stimulus_beat;
   input logic tlast;
   logic [63:0] beat_in;

   // Get beat from packet work sapce
   beat_in = test_packet.get_beat;
   // Push beat into stimulus FIFO
   axis_stimulus_pre.push_payload(beat_in,tlast);
   // Push beat into golden response FIFO with caclulated dispatch time
   axis_golden_pre.write_beat({time_this_sample,beat_in[63:32]},0);
   // Update dispatch time
   time_this_sample = time_this_sample  + clks_per_sample;
   // Push beat into golden response FIFO, possibly with TLAST asserted
   axis_golden_pre.write_beat({time_this_sample,beat_in[31:0]},tlast);
   // Update dispatch time
   time_this_sample = time_this_sample  + clks_per_sample;
   $display("push: time: %d",time_this_sample);
   
endtask

// Fills packet in workspace with random payload and pushes the headers to the FIFO
// (Odd collection of functionality but maximizes code reuse)
task populate_packet;
   input pkt_type_t pkt_type;

   // On last packet of burst change type to INT16_COMPLEX_EOB
   test_packet.set_packet_type(pkt_type);
   // Generate random data in payload....
   test_packet.random;
   // ...then rewind pointer to head of payload again
   test_packet.rewind_payload;
   // Push out Header fields to Stimulus FIFO
   axis_stimulus_pre.push_header(test_packet.get_header());
endtask // populate_header

// Create new packet workspace object and initialize headers
// (Odd collection of functionality but maximizes code reuse)
task initialize_packet_workspace;
   input logic [15:0] payload_bytes;
   input logic [63:0] start_time;

   // Create Object
   test_packet = new;
   // Initialize header fields with default values
   test_packet.init;
   // Overide FlowID
   test_packet.set_flow_src(SRC0);
   test_packet.set_flow_dst(DST0);
   // Set packet length to be header plus 16 beats of 2 complex samples
   test_packet.set_length(16+payload_bytes);
   // Set timestamp of first packet to be 1000...
   test_packet.set_timestamp(start_time);
   // ... and record that to a working variable including
   // +1 increment for 1 cycle of pipeline delay in axis_tx_control
   time_this_sample = test_packet.get_timestamp() + 1;
endtask

endmodule // axis_pkt_to_stream_unit_test
