//-------------------------------------------------------------------------------
// File:    axis_minimal_fifo_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

//`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_minimal_fifo.sv"

module axis_minimal_fifo_unit_test;
  timeunit 1ns; 
  timeprecision 1ps;
  import svunit_pkg::svunit_testcase;

  string name = "axis_minimal_fifo_ut";
  svunit_testcase svunit_ut;

   logic clk;
   logic rst;
   
   axis_slave_t in0(.clk(clk));
   axis_master_t out0(.clk(clk));
   

   logic [63:0] test_tdata;
   logic 	test_tlast;
   logic [1:0] 	space;
   logic [1:0]	occupied;
   
   

   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
   end

   always
     #5 clk <= ~clk;

  //===================================
  // This is the UUT that we're 
  // running the Unit Tests on
  //===================================
  axis_minimal_fifo 
    #(.WIDTH(65))
   my_axis_minimal_fifo
     (
      .clk(clk),
      .rst(rst),
      // In
      .in_tdata({in0.tlast,in0.tdata}),
      .in_tvalid(in0.tvalid),
      .in_tready(in0.tready),
      // Out
      .out_tdata({out0.tlast,out0.tdata}),
      .out_tvalid(out0.tvalid),
      .out_tready(out0.tready),
      // Status 
      .space(space),
      .occupied(occupied)
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


 
   //===================================
   // Test:
   //
   // pass_data
   //
   // Input 0 passes data when selected,
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(pass_data)
   idle_all();
   fork
      begin : master_thread
	
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);	 
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);	 	 
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);	 
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : slave_thread
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
      end
   join
   `SVTEST_END
   //===================================
   // Test:
   //
   // Test occupancy
   //
   // Test FIFO occupancy after each push and pop
   // 
   //===================================
   `SVTEST(test_occupancy)
   idle_all();
   begin: test_occupancy_thread
      `FAIL_UNLESS(space === 2'd2);
      `FAIL_UNLESS(occupied === 2'd0);
      in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
      `FAIL_UNLESS(space === 2'd1);
      `FAIL_UNLESS(occupied === 2'd1);
      in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
      `FAIL_UNLESS(space === 2'd0);
      `FAIL_UNLESS(occupied === 2'd2);
      out0.read_beat(test_tdata,test_tlast);
      `FAIL_UNLESS(space === 2'd1);
      `FAIL_UNLESS(occupied === 2'd1)
      out0.read_beat(test_tdata,test_tlast);
      `FAIL_UNLESS(space === 2'd2);
      `FAIL_UNLESS(occupied === 2'd0);
   end // block: test_occupancy_thread
   `SVTEST_END
   `SVUNIT_TESTS_END

    
    task idle_all();
	in0.idle_master();
       out0.idle_slave();
    endtask // idle_all
   
endmodule
