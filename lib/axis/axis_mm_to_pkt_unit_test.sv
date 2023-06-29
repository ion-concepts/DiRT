//-------------------------------------------------------------------------------
// File:    axis_mm_to_pkt_unit_test.sv
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
//`include "drat_protocol.sv"

module axis_mm_to_pkt_unit_test;
   timeunit 1ns; 
   timeprecision 1ps;
   import drat_protocol::*;
   import svunit_pkg::svunit_testcase;

   string name = "axis_mm_to_pkt_ut";
   svunit_testcase svunit_ut;

   logic clk;
   logic rst;

   // Output bus
   pkt_stream_t out(.clk(clk));
   pkt_stream_t in(.clk(clk));
   pkt_stream_t in_fifo(.clk(clk));
   // Data structure holds input header
   pkt_header_t header_in;
   // Data structure holds output header
   pkt_header_t header_out;

   logic [31:0] upper;
   logic        upper_pls;
   
   logic [31:0] lower_norm;
   logic        lower_norm_pls;
   
   logic [31:0] lower_last;
   logic        lower_last_pls;
   
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
   
   Packet test_packets[];


   
   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
   end

   always
     #5 clk <= ~clk;

   //-------------------------------------------------------------------------------
   // Buffer input data set. (Note doesn't drive UUT directly just stores test stimulus.
   //-------------------------------------------------------------------------------
   wire [10:0] test_fifo_occupied;
   
   axis_fifo
     #(.WIDTH(65),.SIZE(10))
   axis_fifo_i0
     (.clk(clk), .rst(rst),
      .in_tdata({in.axis.tlast,in.axis.tdata}), 
      .in_tvalid(in.axis.tvalid), 
      .in_tready(in.axis.tready),
      .out_tdata({in_fifo.axis.tlast,in_fifo.axis.tdata}), 
      .out_tvalid(in_fifo.axis.tvalid), 
      .out_tready(in_fifo.axis.tready&&ready_to_test),
      .space(), 
      .occupied(test_fifo_occupied));
   
   //===================================
   // This is the UUT that we're 
   // running the Unit Tests on
   //===================================

   axis_mm_to_pkt
     #(
       .FIFO_SIZE(10)
       )
   my_axis_mm_to_pkt
     (
      .clk(clk),
      .rst(rst),
      //-------------------------------------------------------------------------------
      // CSR registers
      //-------------------------------------------------------------------------------
      .upper(upper),
      .upper_pls(upper_pls),
      .lower_norm(lower_norm),
      .lower_norm_pls(lower_norm_pls),
      .lower_last(lower_last),
      .lower_last_pls(lower_last_pls),
      .status(status),
      //-------------------------------------------------------------------------------
      // AXIS Output Bus
      //-------------------------------------------------------------------------------
      .out_tdata(out.axis.tdata),
      .out_tvalid(out.axis.tvalid),
      .out_tlast(out.axis.tlast),
      .out_tready(out.axis.tready)
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
     ready_to_test = 0;
     
     repeat(10) @(posedge clk);
     rst <= 1'b0;
     idle_all();
     upper <= 64'h0;
     upper_pls <= 1'b0;
     lower_norm <= 64'h0;
     lower_norm_pls <= 1'b0;
     lower_last <= 64'h0;
     lower_last_pls <= 1'b0;
     

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
  // Pass good sample data packets
  // 
  //-------------------------------------------------------------------------------
  `SVTEST(random_packets)
  `INFO("Testing random packets");
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
         test_packets[packet_count_in].set_length (beats_to_bytes({$random} % (space-3) + 3));
         space = space - bytes_to_beats(test_packets[packet_count_in].get_length);
         // Generate random payload.
         test_packets[packet_count_in].random;
         // Push new packet into test bench
         in.push_header(test_packets[packet_count_in].get_header);
         test_packets[packet_count_in].rewind_payload;
         for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_in].get_length) - 3) ; x = x + 1)
           in.push_payload(test_packets[packet_count_in].get_beat,0);
         // Set last
         in.push_payload(test_packets[packet_count_in].get_beat,1);

         while (space > 0) begin
            packet_count_in = packet_count_in + 1;
            // Preserve existing packets whilst expanding list
            test_packets = new[packet_count_in+1] (test_packets);
            // Copy header from previous packet and increment sequence ID
            test_packets[packet_count_in] = new;
            test_packets[packet_count_in].set_header(test_packets[packet_count_in-1].get_header);
            test_packets[packet_count_in].inc_seq_id;
            // Add delta to timestamp
            test_packets[packet_count_in].set_timestamp(test_packets[packet_count_in].get_timestamp + 'd100);
            // Unsigned value constrained between min packet size and remaining buffer size.
            test_packets[packet_count_in].set_length (beats_to_bytes({$random} % (space-3) + 3));
            space = space - bytes_to_beats(test_packets[packet_count_in].get_length);
            if (space < 3) begin
               // Make packet bigger so all of last bit of buffer is used.
               test_packets[packet_count_in].set_length(test_packets[packet_count_in].get_length+(space<<3));
               space = 0;
            end
            // Generate random payload.
            test_packets[packet_count_in].random;
            // Push new packet into test bench
            in.push_header(test_packets[packet_count_in].get_header);
            test_packets[packet_count_in].rewind_payload;

            for (x = 0 ; x < (bytes_to_beats(test_packets[packet_count_in].get_length) - 3) ; x = x + 1)
              in.push_payload(test_packets[packet_count_in].get_beat,0);
            // Set last
            in.push_payload(test_packets[packet_count_in].get_beat,1);
         end // while (space > 0)
         ready_to_test = 1;
         `INFO("All test stimulus buffered in FIFO. Now drive MM interface from FIFO.");
         // ...yes this is an obscure way to do this...but the above code was already written and tested....
         while (test_fifo_occupied > 0) begin
            `FAIL_UNLESS(in_fifo.axis.tvalid === 1'b1);
            in_fifo.pull_beat(beat_in,tlast_in);
            put_beat_via_csr(beat_in,tlast_in);
         end
         `INFO("All test stimulus written to MM interface. Source thread exits.");
            
      end // block: mm_source_thread

      begin: pkt_sink_thread
         while (!ready_to_test) @(posedge clk);
          `INFO("Receiving thread now armed.");
         //
         // Access AXIS egress interface to get packets.
         //
         packet_count_out = 0;
         
         while (packet_count_out < packet_count_in)
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
         `INFO("All bus beats received via CSR interface correctly.");
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
      in_fifo.axis.idle_slave();
   endtask // idle_all


   task automatic put_beat_via_csr;
      input [63:0] beat;
      input        last;
      

      begin
         // Wait for space in FIFO
         @(posedge clk) while (status[31]==0) @(posedge clk);
         @(posedge clk);
         upper <= beat[63:32];
         upper_pls <= 1'b1;
         @(posedge clk);
         upper_pls <= 1'b0;
         repeat(2) @(posedge clk);
         if (last) begin
            lower_last <= beat[31:0];
            lower_last_pls <= 1'b1;
            @(posedge clk);
            lower_last_pls <= 1'b0;
         end else begin
            lower_norm <= beat[31:0];
            lower_norm_pls <= 1'b1;
            @(posedge clk);
            lower_norm_pls <= 1'b0;
         end
         @(posedge clk);
      end
   endtask // put_beat_via_csr
   
endmodule

