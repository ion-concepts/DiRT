//-------------------------------------------------------------------------------
// File:    axis_broadcast_to_fifo_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit for axis_braodcast_to_fifo.sv
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"
`include "svunit_defines.svh"
`include "axis_broadcast_to_fifo.sv"

module axis_broadcast_to_fifo_unit_test;
   timeunit 1ns;
   timeprecision 1ps;
   import svunit_pkg::svunit_testcase;
   import drat_protocol::*;
   
   string name = "axis_broadcast_to_fifo_ut";
   svunit_testcase svunit_ut;


   logic  clk;
   logic  rst;
   logic  sw_rst;


   axis_broadcast_t in0(.clk(clk));
   axis_t out0(.clk(clk));

   logic  csr_overflow;
   logic  csr_enable;
   //logic [15:0] src, dst;
   drat_protocol::flow_id_t csr_flow_id;
   logic  csr_match_src, csr_match_dst;

   logic [63:0] test_tdata;
   logic        test_tlast;
   logic [63:0] header;
   int          timeout;

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
   axis_broadcast_to_fifo
     #(
       .FIFO_SIZE(9),
       .MITIGATE_OVERFLOW(1)
       )
   my_axis_broadcast_to_fifo
     (
      .clk(clk),
      .rst(rst),
      .sw_rst(sw_rst),
      //
      // Output Bus
      //
      .out_axis(out0),
      //
      // Input Bus
      //
      .in_axis(in0),
      //
      // Control & Status
      //
      .csr_overflow(csr_overflow),
      .csr_enable(csr_enable),
      .csr_flow_id(csr_flow_id),
      .csr_match_src(csr_match_src),
      .csr_match_dst(csr_match_dst)
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


      repeat(10) @(posedge clk);
      rst <= 1'b0;
      idle_all();
      csr_enable <= 1'b0;
      csr_flow_id.flow_addr.flow_src <= 0;
      csr_flow_id.flow_addr.flow_dst <= 0;
      csr_match_src <= 1'b0;
      csr_match_dst <= 1'b0;


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
     // filter_data
     //
     // Filter on FLOW_ID.DST
     // Only second and fourth packet should pass.
     //
     //===================================
     `SVTEST(filter_data)
   idle_all();
   @(negedge clk);
   csr_enable <= 1'b1;
   csr_flow_id.flow_addr.flow_src <= 16'h0000;
   csr_flow_id.flow_addr.flow_dst <= 16'h00ff;
   csr_match_src <= 1'b0;
   csr_match_dst <= 1'b1;

   @(negedge clk);

   fork
      begin : source_thread
	 // PKT1
	 in0.write_beat(64'hffff_0010_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 in0.write_beat(64'h00ff_0010_0000_00ff,1'b0);
	 in0.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 in0.write_beat(64'h1111_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT3
	 in0.write_beat(64'hffff_0010_ffff_ff00,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 in0.write_beat(64'h00ff_0010_ffff_00ff,1'b0);
	 in0.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 in0.write_beat(64'h2222_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : sink_thread
	 // PKT2
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h00ff_0010_0000_00ff);
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
	 `FAIL_UNLESS(test_tdata === 64'h00ff_0010_ffff_00ff);
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

	 disable watchdog_thread;
      end // block: sink_thread

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
     // filter_data2
     //
     // Filter on FLOW_ID.SRC & FLOW_ID.DST
     // Only the fourth packet should pass.
     //
     //===================================
     `SVTEST(filter_data2)
   idle_all();
   @(negedge clk);
   csr_enable <= 1'b1;
   csr_flow_id.flow_addr.flow_src <= 16'hFFFF;
   csr_flow_id.flow_addr.flow_dst <= 16'h00FF;
   csr_match_src <= 1'b1;
   csr_match_dst <= 1'b1;

   @(negedge clk);

   fork
      begin : source_thread2
	 // PKT1
	 in0.write_beat(64'hffff_0010_ffff_0000,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PK2
	 in0.write_beat(64'h00ff_0010_0000_00ff,1'b0);
	 in0.write_beat(64'h0000_ffff_1111_ffff,1'b0);
	 in0.write_beat(64'h1111_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT3
	 in0.write_beat(64'hffff_0010_ffff_ff00,1'b0);
	 in0.write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in0.write_beat(64'h0000_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 // PKT4
	 in0.write_beat(64'h00ff_0010_ffff_00ff,1'b0);
	 in0.write_beat(64'h0000_ffff_2222_ffff,1'b0);
	 in0.write_beat(64'h2222_0000_0000_0000,1'b0);
	 in0.write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : sink_thread2

	 // PKT4
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h00ff_0010_ffff_00ff);
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

	 disable watchdog_thread2;
      end // block: sink_thread

      begin : watchdog_thread2
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
