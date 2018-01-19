//-----------------------------------------------------------------------------
// File:    axis_demux4_unit_test.sv
//
// Author:  Ian Buckley
//
// Description:
// Set of unit tests using SVUnit
//
//-----------------------------------------------------------------------------

//`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_demux4.sv"

module axis_demux4_unit_test;
  timeunit 1ns; 
  timeprecision 1ps;
  import svunit_pkg::svunit_testcase;

  string name = "axis_demux4_ut";
  svunit_testcase svunit_ut;


   logic clk;
   logic rst;
   
   axis_slave_t in0(.clk(clk));
   axis_master_t out0(.clk(clk));
   axis_master_t out1(.clk(clk));
   axis_master_t out2(.clk(clk));
   axis_master_t out3(.clk(clk));
   logic [63:0] test_tdata;
   logic 	test_tlast;
   logic [63:0] header;

   reg [1:0]   select;
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
  axis_demux4 
    #(
      .WIDTH(64)
      )
   my_axis_demux4
     (
      .clk(clk),
      .rst(rst),
      //
      // External logic supplies egress port selection.
      //
      .header(header),
      .select(select),
      //
      // Output Bus 0
      //
      .out0_tdata(out0.tdata),
      .out0_tvalid(out0.tvalid),
      .out0_tlast(out0.tlast),
      .out0_tready(out0.tready),
      //
      // Output Bus 1
      //
      .out1_tdata(out1.tdata),
      .out1_tvalid(out1.tvalid),
      .out1_tlast(out1.tlast),
      .out1_tready(out1.tready),
      //
      // Output Bus 2
      //
      .out2_tdata(out2.tdata),
      .out2_tvalid(out2.tvalid),
      .out2_tlast(out2.tlast),
      .out2_tready(out2.tready),
      //
      // Output Bus 3
      //
      .out3_tdata(out3.tdata),
      .out3_tvalid(out3.tvalid),
      .out3_tlast(out3.tlast),
      .out3_tready(out3.tready), 
      //
      // Input Bus
      //
      .in_tdata(in0.tdata),
      .in_tvalid(in0.tvalid),
      .in_tlast(in0.tlast), 
      .in_tready(in0.tready)
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
     @(posedge clk);
     rst <= 1'b1;
     select <= 2'h0;
     
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
   // pass_data_only_port0
   //
   // Force "select" input to 0.
   // All packets presented should egress
   // through port0.
   //
   //===================================
   `SVTEST(pass_data_only_port0)
   @(negedge clk);
   select <= 2'h0;
   @(negedge clk);
   
   fork
      begin : source_thread
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 in0.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 in0.write_beat(64'h1111_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : sink0_thread
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
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable sink1_thread;
	 disable sink2_thread;
	 disable sink3_thread;
	 disable watchdog_thread;
	 
      end // block: sink0_thread
      begin : sink1_thread
	 while(1) begin
	    `FAIL_UNLESS(out1.tvalid === 1'b0);
	    @(negedge clk);
	 end
      end
      begin : sink2_thread
	 while(1) begin
	    `FAIL_UNLESS(out2.tvalid === 1'b0);
	    @(negedge clk);
	 end
      end
      begin : sink3_thread
	 while(1) begin
	    `FAIL_UNLESS(out3.tvalid === 1'b0);
	    @(negedge clk);
	 end
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
  //===================================
   // Test:
   //
   // pass_data_switch on lsbs
   //
   // Decode 2 LSB's for select
   //
   //===================================
   `SVTEST(pass_data_switch)
   @(negedge clk);
   select <= 2'h0;
   @(negedge clk);
   
   fork
      begin : select_thread
	 while(1) begin
	    @(negedge clk);
	    select = header[1:0];
	 end
      end
      begin : source_thread
	 //PKT egress port0
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 //PKT egress port1
	 in0.write_beat(64'hffff_1111_ffff_0001,1'b0);
	 in0.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 in0.write_beat(64'h1111_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 //PKT egress port2
	 in0.write_beat(64'hffff_2222_ffff_0002,1'b0);
	 in0.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 in0.write_beat(64'h2222_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 //PKT egress port3
	 in0.write_beat(64'hffff_3333_ffff_0003,1'b0);
	 in0.write_beat(64'h0000_ffff_3333_ffff,1'b0);
	 in0.write_beat(64'h3333_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : sink0_thread
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
	 
      end // block: sink0_thread
      begin : sink1_thread
	 out1.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out1.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_1111_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out1.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h1111_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out1.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
      end
      begin : sink2_thread
	 out2.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_2222_ffff_0002);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out2.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out2.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out2.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
      end
      begin : sink3_thread
	 out3.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_3333_ffff_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out3.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_3333_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out3.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h3333_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out3.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable watchdog_thread;
	 disable select_thread;
	 
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
       out1.idle_slave();
       out2.idle_slave();
       out3.idle_slave();
    endtask // idle_all
   
endmodule
