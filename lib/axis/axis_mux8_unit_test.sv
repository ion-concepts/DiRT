//-------------------------------------------------------------------------------
// File:    axis_mux8_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_mux8_wrapper.sv"

module axis_mux8_unit_test;
   timeunit 1ns; 
   timeprecision 1ps;

   import svunit_pkg::svunit_testcase;

   string name = "axis_mux8_ut";
   svunit_testcase svunit_ut;

   logic  clk;
   logic rst;
   
   axis_t in0(.clk(clk));
   axis_t in1(.clk(clk));
   axis_t in2(.clk(clk));
   axis_t in3(.clk(clk));
   axis_t in4(.clk(clk));
   axis_t in5(.clk(clk));
   axis_t in6(.clk(clk));
   axis_t in7(.clk(clk));

   axis_t out0(.clk(clk));

   logic [63:0] test_tdata;
   logic 	test_tlast;
   
   logic        rendeavous;
   int 		timeout;

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

   axis_mux8_wrapper
     #(
       .BUFFER(0),
       .PRIORITY(0))
   my_axis_mux8
      (
       .clk(clk),
       .rst(rst),
       .in0_axis(in0),
       .in1_axis(in1),
       .in2_axis(in2),
       .in3_axis(in3),
       .in4_axis(in4),
       .in5_axis(in5),
       .in6_axis(in6),
       .in7_axis(in7),
       .out_axis(out0)
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
     rendeavous <= 1'b0;
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
   // input3_followed_by_input0_back_to_back
   //
   // Input 3 the input 0 passes data when selected,
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(input3_followed_by_input0_back_to_back)
   idle_all();
   fork
      begin : master_thread
	 in3.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in3.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in3.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in3.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : slave_thread
	 // Packet 1
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
	 // Packet 2
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
   // input3_followed_by_input4_then_input0_back_to_back
   //
   // Tests ports 4 and 4 fighting for arbitration after port3 finishes.
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(input3_followed_by_input4_then_input0_back_to_back)
   idle_all();
   fork
      begin : input3
	 in3.write_beat(64'hffff_0000_ffff_0003,1'b0);
	 rendeavous <= 1'b1;
	 in3.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in3.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in3.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : input0
	 while (!rendeavous) @(posedge clk);
	 
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : input4
	 while (!rendeavous) @(posedge clk);
	 
	 in4.write_beat(64'hffff_0000_ffff_0004,1'b0);
	 in4.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in4.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in4.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end      
      begin : slave_thread
	 // Packet 1 from port 3
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0003);
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
	 // Packet 2 from port 4
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0004);
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
	 // Packet 3 from port 0
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
      begin : in4_thread
	in4.write_beat(64'h0000_0000_0004_0001,1'b0);
	in4.write_beat(64'h0000_0000_0004_0002,1'b1);
	in4.write_beat(64'h0000_0000_0004_0003,1'b0);
	in4.write_beat(64'h0000_0000_0004_0004,1'b1);	 
      end 
      begin : in5_thread
	in5.write_beat(64'h0000_0000_0005_0001,1'b0);
	in5.write_beat(64'h0000_0000_0005_0002,1'b1);
	in5.write_beat(64'h0000_0000_0005_0003,1'b0);
	in5.write_beat(64'h0000_0000_0005_0004,1'b1);	 	
      end
      begin : in6_thread
       	in6.write_beat(64'h0000_0000_0006_0001,1'b0);
	in6.write_beat(64'h0000_0000_0006_0002,1'b1);
	in6.write_beat(64'h0000_0000_0006_0003,1'b0);
	in6.write_beat(64'h0000_0000_0006_0004,1'b1);	 
      end
      begin : in7_thread
       	in7.write_beat(64'h0000_0000_0007_0001,1'b0);
	in7.write_beat(64'h0000_0000_0007_0002,1'b1);
	in7.write_beat(64'h0000_0000_0007_0003,1'b0);
	in7.write_beat(64'h0000_0000_0007_0004,1'b1);	 
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
	 
	 //in4, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0004_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0004_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in5, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0005_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0)
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0005_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in6, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0006_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0006_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in7, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0007_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0007_0002);
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
 
	 //in4, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0004_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0004_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in5, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0005_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0005_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in6, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0006_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0006_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in7, first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0007_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0007_0004);
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
	in4.idle_master();
	in5.idle_master();
	in6.idle_master();
	in7.idle_master();	
	out0.idle_slave();
     endtask // idle_all
   
endmodule
