//-------------------------------------------------------------------------------
//-- File:    axis_fifo_unit_test.sv
//--
//-- Author:  Ian Buckley
//--
//-- Description:
//-- Set of unit tests using SVUnit
//--
//--
//--
//-------------------------------------------------------------------------------

//`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_fifo.sv"

module axis_fifo_unit_test;
  timeunit 1ns; 
  timeprecision 1ps;
  import svunit_pkg::svunit_testcase;

  string name = "axis_fifo_ut";
  svunit_testcase svunit_ut;

   localparam SIZE=10;
   
   logic clk;
   logic rst;
   
   axis_slave_t in0(.clk(clk));
   axis_master_t out0(.clk(clk));
   

   logic [63:0] test_tdata;
   logic 	test_tlast;
   wire [SIZE:0] space,occupied;
   int 	       timeout;

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
  axis_fifo 
    #(.WIDTH(65),
      .SIZE(SIZE)
      )
   my_axis_fifo
     (
      //-- Clock/Reset
      .clk(clk),
      .rst(rst),
      // -- Input AXI Stream
      .in_tdata({in0.tlast,in0.tdata}),
      .in_tvalid(in0.tvalid),
      .in_tready(in0.tready),
      //-- Output AXI Stream
      .out_tdata({out0.tlast,out0.tdata}),
      .out_tvalid(out0.tvalid),
      .out_tready(out0.tready),
      //-- Current fullness of FIFO
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
      end // block: slave_thread
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
