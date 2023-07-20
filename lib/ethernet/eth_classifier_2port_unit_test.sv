//-------------------------------------------------------------------------------
// File:    eth_classifier_2port_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// 
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"
`include "svunit_defines.svh"
`include "eth_classifier_2port.sv"

module eth_classifier_2port_unit_test;
   timeunit 1ns; 
   timeprecision 1ps;
   //import drat_protocol::*;
   import ethernet_protocol::*;
   import svunit_pkg::svunit_testcase;

   string name = "eth_classifier_2port_ut";
   svunit_testcase svunit_ut;

   logic clk;
   logic rst;

   ///IJB workaround for virtual interface issue with copy_to_pkt. Need a better solution.
   //pkt_stream_t bug_fix_if(.clk(clk));
   
   //
   // Ethernet Axis Busses
   //
   // Pre-Buffer Input Bus
   eth_stream_t in_axis_pre(.clk(clk));
   // Bus between stimulus buffer and valve
   eth_stream_t in_axis_post(.clk(clk));
   // Bus between valve and UUT
   eth_stream_t in_axis(.clk(clk));
   // Bus between UUT egress0 and egress valve
   eth_stream_t out0_axis(.clk(clk));
   // Bus between egress0 valve and FIFO
   eth_stream_t out0_axis_pre(.clk(clk));
   // Bus between egress0 FIFO and response test bench
   eth_stream_t out0_axis_post(.clk(clk));
   // Bus between UUT egress1 and egress valve
   eth_stream_t out1_axis(.clk(clk));
   // Bus between egress0 valve and FIFO
   eth_stream_t out1_axis_pre(.clk(clk));
   // Bus between egress0 FIFO and response test bench
   eth_stream_t out1_axis_post(.clk(clk));
   // Golden response buses for FIFO's
   eth_stream_t in0_axis_golden(.clk(clk));
   eth_stream_t in1_axis_golden(.clk(clk));
   eth_stream_t out0_axis_golden(.clk(clk));
   eth_stream_t out1_axis_golden(.clk(clk));


   
   //
   // CSR
   //
   logic [47:0] csr_mac;
   logic [31:0] csr_ip;   
   logic [15:0] csr_udp0;  
   logic [15:0] csr_udp1;
   logic        csr_expose_drat;
   logic        csr_enable;
   // Declarations for Stimulus Thread(s)
   logic        enable_stimulus;
   logic        enable_response0;
   logic        enable_response1;
   logic        ready_to_test;
   
   // Declarations for Response Thread(s)
   logic [67:0] golden_beat0, response_beat0;
   logic        golden_tlast0, response_tlast0;
   logic [67:0] golden_beat1, response_beat1;
   logic        golden_tlast1, response_tlast1;
   // Watchdog
   integer      timeout;
   
   //
   //
  // EthernetPacket test_packet;
   
   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
   end

   always begin
     #5 clk <= ~clk;
   end

   //===================================
   // This is the UUT that we're 
   // running the Unit Tests on
   //===================================
   eth_classifier_2port eth_classifier_2port_i0
     (
      .clk(clk),
      .rst(rst),
      //
      // Ingress ethernet bus to classify
      //
      .in_axis(in_axis.axis),
      //
      // Two possible egress busses.
      //
      .out0_axis(out0_axis.axis), // Assumed to be default, with full TCP/IP stack downstream, 4 tuser bits included
      .out1_axis(out1_axis.axis),  // Assumed to be DRaT protocol datapath, no tuser bits included.
      //
      // CSR
      //
      .csr_mac(csr_mac),
      .csr_ip(csr_ip),
      .csr_udp0(csr_udp0),
      .csr_udp1(csr_udp1),
      .csr_expose_drat(csr_expose_drat),
      .csr_enable(csr_enable)
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
   axis_fifo_stimulus_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_pre.axis),
      .out_axis(in_axis_post.axis),
      .space(),
      .occupied()
      );


   axis_valve axis_valve_stimulus_i
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_post.axis),
      .out_axis(in_axis.axis),
      .enable(enable_stimulus)
      );

   //-------------------------------------------------------------------------------
   // Buffer output response packet streams 
   //-------------------------------------------------------------------------------

   axis_valve axis_valve_response_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out0_axis.axis),
      .out_axis(out0_axis_pre.axis),
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
      .in_axis(out0_axis_pre.axis),
      .out_axis(out0_axis_post.axis),
      .space(),
      .occupied()
      );

  
   axis_valve axis_valve_response_i1
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out1_axis.axis),
      .out_axis(out1_axis_pre.axis),
      .enable(enable_response1)
      );
   
   axis_fifo_wrapper
     #(
       .SIZE(16)
       )
   axis_fifo_response_i1
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out1_axis_pre.axis),
      .out_axis(out1_axis_post.axis),
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
      .in_axis(in0_axis_golden.axis),
      .out_axis(out0_axis_golden.axis),
      .space(),
      .occupied()
      );

   axis_fifo_wrapper
     #(
       .SIZE(16)
       )
   axis_fifo_golden_i1
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in1_axis_golden.axis),
      .out_axis(out1_axis_golden.axis),
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
      ready_to_test <= 0;
      // Bring CSR"s to reset like values.
      csr_mac <= 0;
      csr_ip <= 0;   
      csr_udp0 <= 0;  
      csr_udp1 <= 0;
      csr_expose_drat <= 1'b0;
      csr_enable <= 1'b0;
      // Open all valves by default
      enable_stimulus <= 1'b1;
      enable_response0 <= 1'b1;
      enable_response1 <= 1'b1;
      // Take all bench AXIS buses to a quiescent state
      idle_all();
      // De-assert reset after 10 clock cycles.
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

   //-------------------------------------------------------------------------------
   // 
   //
   //-------------------------------------------------------------------------------
   `SVTEST(test_udp_port_filtering)
   `INFO("test_udp_port_filtering: Filter UDP packets based on UDP dst port. Port 10 and port 13 go to egress1");
   fork
      begin : load_stimulus
         //
         UDPPacket test_packet;
         //
         @(negedge clk);
         // Load sensible CSR values
         csr_mac <= {8'd0,8'd6,8'd7,8'd8,8'd9,8'd10};
         csr_ip <= {8'd5,8'd6,8'd7,8'd8};   
         csr_udp0 <= 'd10;  
         csr_udp1 <= 'd13;
         csr_expose_drat <= 1'b0;
         @(negedge clk);
         csr_enable <= 1'b1;

         // Open valves to isolate UUT
         enable_stimulus <= 0;
         for (integer i = 0; i < 15; i++) begin
            // Reconstruct (and initialize) packet each iteration
            // Packet size grows 1 octet each time.
            // Need to set TUSER bits appropriately in response to valid octets in
            // last beat like simple_gemac would
            test_packet = UDPPacket::new(i); 
            test_packet.add_payload_octet(i[7:0]);
            test_packet.set_udp_src_port(i[15:0]+1); 
            test_packet.set_udp_dst_port(i[15:0]); 
            test_packet.set_ipv4_src_addr({8'd1,8'd2,8'd3,8'd4});
            test_packet.set_ipv4_dst_addr({8'd5,8'd6,8'd7,8'd8});
            test_packet.set_mac_src({8'd0,8'd1,8'd2,8'd3,8'd4,8'd5});
            test_packet.set_mac_dst({8'd0,8'd6,8'd7,8'd8,8'd9,8'd10});
            test_packet.send_udp_to_eth_stream(in_axis_pre,1);
            // Add bus beats to Golden response FIFO's
            if ((i==10) || (i==13)) begin
               test_packet.send_udp_to_eth_stream(in1_axis_golden,1);
            end else begin
               test_packet.send_udp_to_eth_stream(in0_axis_golden,1);
            end
         end // for (integer i = 0; i < 32; i++)
         //
         // Stimulus fully loaded, initialise system for test and release stimulus
         // by opening valve.
         //
         @(negedge clk);
         @(negedge clk);
         // 100% duty cycle on AXIS input bus.
         enable_stimulus <= 1'b1;
         // Let response threads run
         ready_to_test <= 1;
         //
         `INFO("test_udp_port_filtering: Stimulus Done");
         //
      end // block: load_stimulus
      
      // Response thread for out0
      begin: read_response_out0
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         `INFO("test_udp_port_filtering: read_response_out0 running");
         // 100% duty cycle on output buses
         enable_response0 <= 1'b1;
         // While golden response FIFO not empty
         while (out0_axis_golden.axis.tvalid) begin
            // Pop golden response.
            out0_axis_golden.axis.read_beat(golden_beat0,golden_tlast0);
            // Pop response.
            out0_axis_post.axis.read_beat(response_beat0,response_tlast0);
            // Compare response to golden
            `FAIL_UNLESS_EQUAL(golden_beat0,response_beat0);
            `FAIL_UNLESS_EQUAL(golden_tlast0,response_tlast0);
         end // while (out0_axis_golden.axis.tvalid)
         `INFO("test_udp_port_filtering: read_response_out0 finished");
      end // block: read_response_out0
      
      // Response thread for out1
      begin: read_response_out1
         // Wait until stimulus is loaded.
         while (!ready_to_test) @(posedge clk);
         `INFO("test_udp_port_filtering: read_response_out1 running");
         // 100% duty cycle on output buses
         enable_response1 <= 1'b1;
         // While golden response FIFO not empty
         while (out1_axis_golden.axis.tvalid) begin
            // Pop golden response.
            out1_axis_golden.axis.read_beat(golden_beat1,golden_tlast1);
            // Pop response.
            out1_axis_post.axis.read_beat(response_beat1,response_tlast1);
            // Compare response to golden
            `FAIL_UNLESS_EQUAL(golden_beat1,response_beat1);
            `FAIL_UNLESS_EQUAL(golden_tlast1,response_tlast1);
         end // while (out1_axis_golden.axis.tvalid)
         `INFO("test_udp_port_filtering: read_response_out1 finished");
         disable watchdog_thread;
      end // block: read_response_out1
      
      begin : watchdog_thread
         timeout = 500000;
         while(1) begin
            `FAIL_IF(timeout==0);
            timeout = timeout - 1;
            @(posedge clk);
         end
      end // block: watchdog_thread
   join
   `SVTEST_END

  `SVUNIT_TESTS_END


    task idle_all();
       in_axis_pre.axis.idle_master();
       out0_axis_post.axis.idle_slave();
       out1_axis_post.axis.idle_slave();
       in0_axis_golden.axis.idle_master();
       in1_axis_golden.axis.idle_master();
       out0_axis_golden.axis.idle_slave();
       out1_axis_golden.axis.idle_slave();
       
    endtask // idle_all

endmodule // eth_classifier_2port_unit_test
