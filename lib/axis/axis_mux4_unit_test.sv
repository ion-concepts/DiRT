//-------------------------------------------------------------------------------
//-- File:    axis_mux4_unit_test.sv
//--
//-- Author:  Ian Buckley
//--
//-- Description:
//-- Set of unit tests using SVUnit
//--
//--
//--
//-------------------------------------------------------------------------------
`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_mux4.sv"
`ifndef _AXIS_SV_
`include "axis.sv"
`endif

module axis_mux4_unit_test;
   timeunit 1ns; 
   timeprecision 1ps;
   import svunit_pkg::svunit_testcase;

   string name = "axis_mux4_ut";
   svunit_testcase svunit_ut;

   logic  clk;
   logic  rst;
   
   axis_slave_t in0(.clk(clk));
   axis_slave_t in1(.clk(clk));
   axis_slave_t in2(.clk(clk));
   axis_slave_t in3(.clk(clk));
   axis_master_t out0(.clk(clk));
   

   logic [63:0] test_tdata;
   logic 	test_tlast;
   int 		timeout;
  

   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
      rst <= 1'b0;
      
   end

   always
     #5 clk <= ~clk;

   //===================================
   // This is the UUT that we're 
   // running the Unit Tests on
   //===================================
   axis_mux4 #(
	       .WIDTH(64), 
	       .BUFFER(0), 
	       .PRIORITY(0))
   my_axis_mux4_0(
		  .clk(clk),
		  .rst(rst),
		  // In0
		  .in0_tdata(in0.tdata),
		  .in0_tvalid(in0.tvalid),
		  .in0_tready(in0.tready),
		  .in0_tlast(in0.tlast),
		  // In1
		  .in1_tdata(in1.tdata),
		  .in1_tvalid(in1.tvalid),
		  .in1_tready(in1.tready),
		  .in1_tlast(in1.tlast),
		  // In2
		  .in2_tdata(in2.tdata),
		  .in2_tvalid(in2.tvalid),
		  .in2_tready(in2.tready),
		  .in2_tlast(in2.tlast),
		  // In3
		  .in3_tdata(in3.tdata),
		  .in3_tvalid(in3.tvalid),
		  .in3_tready(in3.tready),
		  .in3_tlast(in3.tlast),
		  // Out
		  .out_tdata(out0.tdata),
		  .out_tvalid(out0.tvalid),
		  .out_tready(out0.tready),
		  .out_tlast(out0.tlast));

  
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
   // input0_others_defined
   //
   // Input 0 passes data when selected,
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(input0_others_defined)
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
   
   //===================================
   // Test:
   //
   // round_robin
   //
   // 
   // All inputs have pending transactions. 
   // Transactions should proceed in round robin order.
   //===================================

   `SVTEST(round_robin)
   fork
      begin : in0_thread
	in0.write_beat(64'h0000_0000_0000_0001,1'b0);
	in0.write_beat(64'h0000_0000_0000_0002,1'b1);
	in0.write_beat(64'h0000_0000_0000_0003,1'b0);
	in0.write_beat(64'h0000_0000_0000_0004,1'b1);	 
      end 
      begin : in1_thread
	in1.write_beat(64'h0000_0000_0001_0001,1'b0);
	in1.write_beat(64'h0000_0000_0001_0002,1'b1);
	in1.write_beat(64'h0000_0000_0001_0003,1'b0);
	in1.write_beat(64'h0000_0000_0001_0004,1'b1);	 	
      end
      begin : in2_thread
       	in2.write_beat(64'h0000_0000_0002_0001,1'b0);
	in2.write_beat(64'h0000_0000_0002_0002,1'b1);
	in2.write_beat(64'h0000_0000_0002_0003,1'b0);
	in2.write_beat(64'h0000_0000_0002_0004,1'b1);	 
      end
      begin : in3_thread
       	in3.write_beat(64'h0000_0000_0003_0001,1'b0);
	in3.write_beat(64'h0000_0000_0003_0002,1'b1);
	in3.write_beat(64'h0000_0000_0003_0003,1'b0);
	in3.write_beat(64'h0000_0000_0003_0004,1'b1);	 
      end
      begin : out0_thread
	 //in0, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in1, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0)
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in2, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in3, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in0, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in1, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in2, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in3, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable watchdog_thread;
      end // block: out0_thread
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
   `SVUNIT_TESTS_END


     task idle_all();
	in0.idle_master();
	in1.idle_master();
	in2.idle_master();
	in3.idle_master();
	out0.idle_slave();
     endtask // idle_all
   
endmodule
