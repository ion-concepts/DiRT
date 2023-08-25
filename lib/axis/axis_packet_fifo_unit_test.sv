//-------------------------------------------------------------------------------
// File:    axis_packet_fifo_unit_test.sv
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
`include "axis_packet_fifo.sv"
`include "axis_fifo.sv"

module axis_packet_fifo_unit_test;
  timeunit 1ns; 
  timeprecision 1ps;
  import svunit_pkg::svunit_testcase;

  string name = "axis_packet_fifo_ut";
  svunit_testcase svunit_ut;

   localparam SIZE=10;
   localparam PACKETS=8;

   logic clk;
   logic rst;

   axis_t #(.WIDTH(64))  in0(.clk(clk));
   axis_t #(.WIDTH(64))  out0(.clk(clk));
 

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

  
  axis_packet_fifo_wrapper
    #(
      .SIZE(SIZE),
      .MAX_PACKETS(PACKETS)
      )
   my_axis_packet_fifo
     (
      .clk(clk),
      .rst(rst),
      .sw_rst(1'b0),
      .in_axis(in0),
      .out_axis(out0),
      // Occupancy
      .space(space),
      .occupied(occupied),
      .packet_count(packet_count)
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
   in0.idle_master();
   out0.idle_slave();
endtask // idle_all

endmodule
