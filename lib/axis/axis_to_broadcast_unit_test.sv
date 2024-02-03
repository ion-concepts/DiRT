//-------------------------------------------------------------------------------
// File:    axis_to_broadcast_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit for axis_to_braodcast.sv
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"
`include "svunit_defines.svh"
`include "axis_broadcast_to_fifo.sv"

module axis_to_broadcast_unit_test;
   timeunit 1ns;
   timeprecision 1ps;
   import svunit_pkg::svunit_testcase;

   string name = "axis_to_broadcast_ut";
   svunit_testcase svunit_ut;

   axis_broadcast_t #(.WIDTH(32)) out0(.clk(clk));
   axis_t  #(.WIDTH(32)) in0(.clk(clk));

   //===================================
   // This is the UUT that we're
   // running the Unit Tests on
   //===================================

   axis_to_broadcast uut
     (
      .axis_in(in0),
      .axis_out(out0)
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
      in0.idle_master();
      

   endtask // setup
   

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
   in0.tdata = 32'h1234_5678;
   in0.tvalid = 1'b0;
   in0.tlast = 1'b0;
   
   #1 `FAIL_UNLESS(out0.tdata ===32'h1234_5678);
   `FAIL_UNLESS(out0.tvalid === 1'b0);
   `FAIL_UNLESS(out0.tlast === 1'b0);
   `FAIL_UNLESS(in0.tready === 1'b1);

   #1 in0.tdata = 32'h8765_4321;
   in0.tvalid = 1'b1;
   in0.tlast = 1'b1;
   
   #1 `FAIL_UNLESS(out0.tdata ===32'h1234_5678);
   `FAIL_UNLESS(out0.tvalid === 1'b0);
   `FAIL_UNLESS(out0.tlast === 1'b1);
   `FAIL_UNLESS(in0.tready === 1'b1);
   in0.tdata = 32'h1234_5678;
   in0.tvalid = 1'b0;
   in0.tlast = 1'b0;
   
   #1 `FAIL_UNLESS(out0.tdata ===32'h1234_5678);
   `FAIL_UNLESS(out0.tvalid === 1'b0);
   `FAIL_UNLESS(out0.tlast === 1'b0);
   `FAIL_UNLESS(in0.tready === 1'b1);
   #1;
   
   `SVTEST_END


   `SVUNIT_TESTS_END

  endmodule // axis_to_broadcast_unit_test
