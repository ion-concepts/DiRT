//-------------------------------------------------------------------------------
// File:    axis_filter_backpressured_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit for
// axis_filter_backpressured.sv
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`include "global_defs.svh"
`include "svunit_defines.svh"
`include "axis_filter_backpressured.sv"

module axis_filter_backpressured_unit_test;
   timeunit 1ns;
   timeprecision 1ps;
   import svunit_pkg::svunit_testcase;

   string name = "axis_filter_backpressured_ut";
   svunit_testcase svunit_ut;

   localparam SIZE_STIM=10;
   localparam SIZE_RESP=11;


   logic  clk;
   logic  rst;
   logic  sw_rst;
   

   // Pre-Buffer Input Bus
   axis_t #(.WIDTH(64)) axis_stimulus_pre(.clk(clk));
   // Bus between stimulus buffer and valve
   axis_t #(.WIDTH(64)) axis_stimulus_post(.clk(clk));
   // Bus between stimulus valve and UUT
   axis_t #(.WIDTH(64)) axis_stimulus_gated(.clk(clk));

   // DUT Output bus
   axis_t #(.WIDTH(64)) axis_response_gated(.clk(clk));
   // Bus between response vavle and buffer
   axis_t #(.WIDTH(64)) axis_response_pre(.clk(clk));
   // Post Buffer Output bus
   axis_t #(.WIDTH(64)) axis_response_post(.clk(clk));
   
   //axis_t in0(.clk(clk));
   //axis_t out0(.clk(clk));
   
   // Declarations for Stimulus/Response Thread(s)
   logic        enable_stimulus;
   logic        enable_response;
   logic	ready_to_test;
   logic [63:0] test_tdata;
   logic        test_tlast;
   logic [63:0] header;
   logic        pass;
   logic        enable;
   // Watchdog
   int 		timeout;

   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
   end

   always
     #5 clk <= ~clk;

   //-------------------------------------------------------------------------------
   // Buffer input sample stream
   //-------------------------------------------------------------------------------

   axis_fifo_wrapper  #(
                        .SIZE(SIZE_STIM)
                        )
   axis_fifo_stimulus_i (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_stimulus_pre),
                         .out_axis(axis_stimulus_post),
                         //-- Current fullness of FIFO
                         .space(),
                         .occupied()
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
   axis_filter_backpressured 
     #(
       .WIDTH(64)
       )
   my_axis_filter_backpressured
     (
      .clk(clk),
      .rst(rst),
      .sw_rst(sw_rst),
      //
      // External logic supplies filter logic
      //
      .header(header),
      .pass(pass),
      //
      // Output Bus
      //
      .out_axis(axis_response_gated),
      //
      // Input Bus
      //
      .in_axis(axis_stimulus_gated),
      //
      // Control
      //
      .enable(enable)
      );

   //-------------------------------------------------------------------------------
   // Buffer output response sample stream
   //-------------------------------------------------------------------------------
   axis_valve axis_valve_response_i (
                                     .clk(clk),
                                     .rst(rst),
                                     .in_axis(axis_response_gated),
                                     .out_axis(axis_response_pre),
                                     .enable(enable_response)
                                     );

   axis_fifo_wrapper  #(
                        .SIZE(SIZE_RESP)
                        )
   axis_fifo_response_i (
                         .clk(clk),
                         .rst(rst),
                         .in_axis(axis_response_pre),
                         .out_axis(axis_response_post),
                         //-- Current fullness of FIFO
                         .space(),
                         .occupied()
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
      // Open all valves by default
      enable_stimulus <= 1'b1;
      enable_response <= 1'b1;
      // Take all bench AXIS buses to a quiescent state
      idle_all();
      // Reset UUT
      rst <= 1'b1;
      sw_rst <= 1'b0;
      enable <= 1'b0;
      pass <= 1'b0;
      
      
      repeat(10) @(posedge clk);
      rst <= 1'b0;
      enable <= 1'b1;
      

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

     //===================================
     // Test:
     //
     // pass_data
     //
     // Force "pass" input to 1.
     // All packets should pass.
     //
     //===================================
     `SVTEST(pass_data)
   idle_all();
   @(negedge clk);
   pass <= 1'b1;
   @(negedge clk);
   
   fork
      begin : source_thread
	 // Response threads can't run until stimulus loaded.
         ready_to_test <= 0;
         // Close valve after stimulus buffer
         enable_stimulus <= 1'b0;
	 // Load test pattern
	 axis_stimulus_pre.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         `INFO("pass_data: Stimulus Done");
         //
      end
      begin : sink_thread
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);

	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
         
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //
	 `INFO("pass_data: Good Response");
	 disable watchdog_thread;
      end // block: sink_thread
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


     //===================================
     // Test:
     //
     // filter_data
     //
     // Filter on all bits of header.
     // Only second packet should pass.
     //
     //===================================
     `SVTEST(filter_data)
   idle_all();
   @(negedge clk);
   pass <= 1'b0;
   @(negedge clk);
   
   fork
      begin : filter_thread
	 while(1) begin
	    @(negedge clk);
	    if (header === 64'hffff_1111_ffff_0000) 
	      pass <= 1'b1;
	    else
	      pass <= 1'b0;
	 end
      end
      begin : source_thread
	 // PKT1
	 axis_stimulus_pre.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT3
	 axis_stimulus_pre.write_beat(64'hffff_2222_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h2222_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h2222_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h2222_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h2222_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h2222_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h1111_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 axis_stimulus_pre.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 axis_stimulus_pre.write_beat(64'h2222_0000_0000_0000,1'b0);
	 axis_stimulus_pre.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
         // Let response threads run
         ready_to_test <= 1;
         //
         // 1000 clock cycles of 66% duty cycle on AXIS input bus
         // then go 100% duty cycle
         //
         repeat(333) begin
            enable_stimulus <= 1'b0;
            @(negedge clk);
            enable_stimulus <= 1'b1;
	    @(negedge clk);
            @(negedge clk);
         end
	 //
         `INFO("filter_data: Stimulus Done");
      end
      begin : sink_thread
	 // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);

	 // PKT2
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT4
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT2
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT4
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT2
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT4
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT2
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT4
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT2
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT4
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT2
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // PKT4
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 axis_response_post.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //
         `INFO("filter: Good Response");
	 disable filter_thread;
	 disable modulate_output_thread;
	 disable watchdog_thread;
      end // block: sink_thread
      begin: modulate_output_thread
	 // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);

	 //
         // 1000 clock cycles of 25% duty cycle on AXIS output bus
         // then go 100% duty cycle
         //
         repeat(250) begin
            enable_response <= 1'b0;
            @(negedge clk);
	    @(negedge clk);
            @(negedge clk);	    
            enable_response <= 1'b1;
	    @(negedge clk);
         end
 
	 enable_response <= 1'b1;
	 `INFO("filter: Back pressure done");
      end
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
    
       task idle_all();
          axis_stimulus_pre.idle_master();
          axis_response_post.idle_slave();
       endtask // idle_all
   
endmodule
