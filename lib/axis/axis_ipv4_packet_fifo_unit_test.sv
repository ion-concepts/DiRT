//-------------------------------------------------------------------------------
// File:    axis_ipv4_packet_fifo_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_ipv4_packet_fifo.sv"
`include "axis_fifo.sv"

module axis_ipv4_packet_fifo_unit_test;
  timeunit 1ns; 
  timeprecision 1ps;
  import svunit_pkg::svunit_testcase;

  string name = "axis_ipv4_packet_fifo_ut";
  svunit_testcase svunit_ut;

   localparam SIZE=10;
   localparam PACKETS=8;

   logic clk;
   logic rst;

   //
   // Ethernet Axis Busses
   //
   // Pre-Buffer Input Bus
   axis_t #(.WIDTH(64)) in_axis_pre(.clk(clk));
   // Bus between stimulus buffer and valve
   axis_t #(.WIDTH(64)) in_axis_post(.clk(clk));
   // Bus between valve and UUT
   axis_t #(.WIDTH(64)) in_axis(.clk(clk));
   // Bus between UUT egress0 and egress valve
   axis_t #(.WIDTH(64)) out_axis(.clk(clk));
   // Bus between egress0 valve and FIFO
   axis_t #(.WIDTH(64)) out_axis_pre(.clk(clk));
   // Bus between egress0 FIFO and response test bench
   axis_t #(.WIDTH(64)) out_axis_post(.clk(clk));
   // Golden response buses for FIFO's
   axis_t #(.WIDTH(64)) in_axis_golden(.clk(clk));
   axis_t #(.WIDTH(64)) out_axis_golden(.clk(clk));

   logic csr_reset_stats;
   logic [31:0] csr_buffered_packets;
   logic [31:0] csr_dropped_packets;
   

   logic [63:0]   test_tdata;
   logic          test_tlast;
   logic [SIZE:0]  space, occupied;
   logic [PACKETS-1:0] packet_count;
   int                timeout;

   //
   // Generate clk
   //
   initial begin
      clk <= 1'b0;
   end

   always
     #5 clk <= ~clk;

  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================

  
  axis_ipv4_packet_fifo
    #(
      .SIZE(SIZE),
      .MAX_PACKETS(PACKETS)
      )
   my_axis_ipv4_packet_fifo
     (
      .clk(clk),
      .rst(rst),
      //
      // CSR interface
      //
      .csr_reset_stats(csr_reset_stats),
      .csr_buffered_packets(csr_buffered_packets),
      .csr_dropped_packets(csr_dropped_packets),
      .in_axis(in_axis),
      .out_axis(out_axis)
      );

 
   //-------------------------------------------------------------------------------
   // Buffer input stimulus packet stream.
   // Pass first to a FIFO to buffer test stimulus.
   // Then a valve so that the buffer can be loaded, then bursted,
   // at full rate, or be modulated to reduce the rate.
   //-------------------------------------------------------------------------------

   axis_fifo_wrapper
     #(
       .SIZE(16)
       )
   axis_fifo_stimulus_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_pre),
      .out_axis(in_axis_post),
      .space(),
      .occupied()
      );

   axis_valve axis_valve_stimulus_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_post),
      .out_axis(in_axis),
      .enable(enable_stimulus)
      );

   //-------------------------------------------------------------------------------
   // Buffer output response packet streams
   //-------------------------------------------------------------------------------

   axis_valve axis_valve_response_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out_axis),
      .out_axis(out_axis_pre),
      .enable(enable_response0)
      );

   axis_fifo_wrapper
     #(
       .SIZE(16)
       )
   axis_fifo_response_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out_axis_pre),
      .out_axis(out_axis_post),
      .space(),
      .occupied()
      );

   //-------------------------------------------------------------------------------
   // Buffer golden response packet streams
   //-------------------------------------------------------------------------------

   axis_fifo_wrapper
     #(
       .SIZE(16)
       )
   axis_fifo_golden_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_golden),
      .out_axis(out_axis_golden),
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
     // Reset UUT
     @(posedge clk);
     rst <= 1'b1;
     idle_all();
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


  //===================================
  // Test:
  //
  // pass_data
  //
  // Feed packets to fifo
  // Check all emerge in order and unaltered.
  //===================================
  `SVTEST(pass_data)

  idle_all();

  fork
/*
     begin : master_thread
	// PKT1
	in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	// PKT2
	in0.write_beat(64'hffff_1111_ffff_1111,1'b0);
	in0.write_beat(64'h1111_ffff_1111_ffff,1'b0);
	in0.write_beat(64'h1111_1111_1111_1111,1'b0);
	in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
     end
     begin : slave_thread
	// PKT1
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0000);
	`FAIL_UNLESS(test_tlast === 1'b0);
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	`FAIL_UNLESS(test_tlast === 1'b0);
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	`FAIL_UNLESS(test_tlast === 1'b0);
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	`FAIL_UNLESS(test_tlast === 1'b1);
	// PKT2
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_1111);
	`FAIL_UNLESS(test_tlast === 1'b0);
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'h1111_ffff_1111_ffff);
	`FAIL_UNLESS(test_tlast === 1'b0);
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'h1111_1111_1111_1111);
	`FAIL_UNLESS(test_tlast === 1'b0);
	out0.read_beat(test_tdata,test_tlast);
	`FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	`FAIL_UNLESS(test_tlast === 1'b1);
	disable watchdog_thread;
  end
 */
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
   in_axis.idle_master();
   out_axis.idle_slave();
endtask // idle_all

endmodule
