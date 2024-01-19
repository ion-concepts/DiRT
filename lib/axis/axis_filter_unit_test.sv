//-------------------------------------------------------------------------------
// File:    axis_filter_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit for
// axis_filter.sv
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`include "global_defs.svh"
`include "svunit_defines.svh"
`include "axis_filter.sv"

module axis_filter_unit_test;
   timeunit 1ns;
   timeprecision 1ps;
   import svunit_pkg::svunit_testcase;

   string name = "axis_filter_ut";
   svunit_testcase svunit_ut;


   logic  clk;
   logic  rst;
   logic  sw_rst;
   
   
   axis_broadcast_t in0(.clk(clk));
   axis_t out0(.clk(clk));
   

   logic [63:0] test_tdata;
   logic        test_tlast;
   logic [63:0] header;
   logic        pass;
   logic        overflow;
   logic        enable;
   

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
   axis_filter 
     #(
       .WIDTH(64)
       )
   my_axis_filter
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
      .out_axis(out0),
      //
      // Input Bus
      //
      .in_axis(in0),
      //
      // Status Flags
      //
      .overflow(overflow),
      //
      // Control
      //
      .enable(enable)
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
      sw_rst <= 1'b0;
      enable <= 1'b0;
      
      
      repeat(10) @(posedge clk);
      rst <= 1'b0;
      idle_all();
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
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 in0.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 in0.write_beat(64'h1111_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : sink_thread


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
	 disable overflow_thread;
      end // block: sink_thread
      begin : overflow_thread
	 while (1) begin
	    `FAIL_UNLESS(overflow === 1'b0);
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
	 in0.write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 in0.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 in0.write_beat(64'h1111_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT3
	 in0.write_beat(64'hffff_2222_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 in0.write_beat(64'hffff_1111_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 in0.write_beat(64'h2222_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : sink_thread
	 // PKT2
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
	 // PKT4
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_1111_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_2222_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h2222_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 
	 disable overflow_thread;
	 disable filter_thread;
      end // block: sink_thread
      begin : overflow_thread
	 while (1) begin
	    `FAIL_UNLESS(overflow === 1'b0);
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
