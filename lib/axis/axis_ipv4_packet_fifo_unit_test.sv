//-------------------------------------------------------------------------------
// File:    axis_ipv4_packet_fifo_unit_test.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Verify thtat:
// * axis_ipv4_packet_fifo buffers packets correctly
// * Discards ingressing packets due to lack of capacity
//
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`include "global_defs.svh"
`include "svunit_defines.svh"
`include "axis_ipv4_packet_fifo.sv"
`include "ethernet.sv"

module axis_ipv4_packet_fifo_unit_test;
   timeunit 1ns;
   timeprecision 1ps;
   import ethernet_protocol::*;
   import svunit_pkg::svunit_testcase;

   string name = "axis_ipv4_packet_fifo_ut";
   svunit_testcase svunit_ut;

   localparam SIZE=10;
   localparam PACKETS=8;

   logic clk;
   logic rst;

   //
   // Ethernet Axis Busses
   //
   // Pre-Buffer Input Bus
   axis_t #(.WIDTH(64)) in_axis_pre(.clk(clk));
   // Bus between stimulus buffer and valve
   axis_t #(.WIDTH(64)) in_axis_post(.clk(clk));
   // Bus between valve and UUT
   axis_t #(.WIDTH(64)) in_axis(.clk(clk));
   // Bus between UUT egress0 and egress valve
   axis_t #(.WIDTH(64)) out_axis(.clk(clk));
   // Bus between egress0 valve and FIFO
   axis_t #(.WIDTH(64)) out_axis_pre(.clk(clk));
   // Bus between egress0 FIFO and response test bench
   axis_t #(.WIDTH(64)) out_axis_post(.clk(clk));
   // Golden response buses for FIFO's
   axis_t #(.WIDTH(64)) in_axis_golden(.clk(clk));
   axis_t #(.WIDTH(64)) out_axis_golden(.clk(clk));

   logic csr_reset_stats;
   logic [31:0] csr_buffered_packets;
   logic [31:0] csr_dropped_packets;

   // Declarations for Stimulus Thread(s)
   logic        enable_stimulus;
   logic        enable_response;
   logic        ready_to_test;

   // Declarations for Response Thread(s)
   logic [67:0] golden_beat, response_beat;
   logic        golden_tlast, response_tlast;

   // Watchdog
   int          timeout;

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


  axis_ipv4_packet_fifo
    #(
      .SIZE(SIZE),
      .MAX_PACKETS(PACKETS)
      )
   my_axis_ipv4_packet_fifo
     (
      .clk(clk),
      .rst(rst),
      //
      // CSR interface
      //
      .csr_reset_stats(csr_reset_stats),
      .csr_buffered_packets(csr_buffered_packets),
      .csr_dropped_packets(csr_dropped_packets),
      .in_axis(in_axis),
      .out_axis(out_axis)
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
   axis_fifo_stimulus_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_pre),
      .out_axis(in_axis_post),
      .space(),
      .occupied()
      );

   axis_valve axis_valve_stimulus_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(in_axis_post),
      .out_axis(in_axis),
      .enable(enable_stimulus)
      );

   //-------------------------------------------------------------------------------
   // Buffer output response packet streams
   //-------------------------------------------------------------------------------

   axis_valve axis_valve_response_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out_axis),
      .out_axis(out_axis_pre),
      .enable(enable_response)
      );

   axis_fifo_wrapper
     #(
       .SIZE(16)
       )
   axis_fifo_response_i0
     (
      .clk(clk),
      .rst(rst),
      .in_axis(out_axis_pre),
      .out_axis(out_axis_post),
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
      .in_axis(in_axis_golden),
      .out_axis(out_axis_golden),
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
      csr_reset_stats <= 0;
      // Open all valves by default
      enable_stimulus <= 1'b1;
      enable_response <= 1'b1;
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


  //===================================
  // Test:
  //
  // pass_data
  //
  // Feed packets to fifo
  // Check all emerge in order and unaltered.
  //===================================
  `SVTEST(pass_data)
  `INFO("pass_data: Pass UDP/IPv4 packets through FIFO without filling it or discarding packets");

  fork
     begin : load_stimulus
        //
        UDPPacket test_packet;
        //
        // Reset statistics registers
        csr_reset_stats <= 0;
        @(negedge clk);
        csr_reset_stats <= 1;
        @(negedge clk);
        csr_reset_stats <= 0;
        @(negedge clk);
        // Open valves to isolate UUT
        enable_stimulus <= 0;
        // Build 16 UDP packets to flow through buffer
        // Keep sizes within buffer total size so that no packet is a discard candidate.
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
           test_packet.set_mac_src({8'd0,8'd1,8'd2,8'd3,8'd4,8'd5}); // Unused
           test_packet.set_mac_dst({8'd0,8'd6,8'd7,8'd8,8'd9,8'd10}); // Unused
           // Queue packet to UUT
           test_packet.send_udp_to_ipv4_stream(in_axis_pre,1);
           // Add Packet to Golden response FIFO
           test_packet.send_udp_to_ipv4_stream(in_axis_golden,1);
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
        `INFO("pass_data: Stimulus Done");
        //
     end // block: load_stimulus


     // Response thread for output
     begin: read_response_out
        // Wait until stimulus is loaded.
        while (!ready_to_test) @(posedge clk);
        `INFO("pass_data: read_response_out running");
        // 100% duty cycle on output buses
        enable_response <= 1'b1;
        // While golden response FIFO not empty
        while (out_axis_golden.tvalid) begin
           // Pop golden response.
           out_axis_golden.read_beat(golden_beat,golden_tlast);
           // Pop response.
           out_axis_post.read_beat(response_beat,response_tlast);
           // Compare response to golden
           `FAIL_UNLESS_EQUAL(golden_beat,response_beat);
           `FAIL_UNLESS_EQUAL(golden_tlast,response_tlast);
        end // while (out0_axis_golden.tvalid)
        // Check CSR status registers hold correct values.
        `FAIL_UNLESS(csr_buffered_packets === 32'd15)
        `FAIL_UNLESS(csr_dropped_packets === 32'd0)
        `INFO("pass_data: read_response_out finished");
        disable watchdog_thread;
     end // block: read_response_out

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
  // drop_packet
  //
  // Feed packets to fifo until full.
  // Feed one more that gets dropped.
  // Then feed a smaller packet that fits.
  // Check all emerge in order and unaltered.
  //===================================
  `SVTEST(drop_packet)
  `INFO("drop_packet: Pass UDP/IPv4 packets through FIFO, filling it, and discarding 8th large packet, then adding more small packets");

  fork
     begin : load_stimulus
        //
        UDPPacket test_packet;
        //
        // Reset statistics registers
        csr_reset_stats <= 0;
        @(negedge clk);
        csr_reset_stats <= 1;
        @(negedge clk);
        csr_reset_stats <= 0;
        @(negedge clk);
        // Close valve to load UUT immediately as we crreate packets
        enable_stimulus <= 1;
        // Build 8 1KB UDP packets to fill buffer...last one should get dropped...leaving less than 1KB free in buffer
        // Keep sizes within buffer total size so that no packet is a discard candidate.
        for (integer i = 0; i < 8; i++) begin
           // Reconstruct (and initialize) packet each iteration
           // Packet size grows 1 octet each time.
           // Need to set TUSER bits appropriately in response to valid octets in
           // last beat like simple_gemac would
           test_packet = UDPPacket::new(1024); //1024+32 octet packets
           test_packet.set_udp_src_port(i[15:0]+1);
           test_packet.set_udp_dst_port(i[15:0]);
           test_packet.set_ipv4_src_addr({8'd1,8'd2,8'd3,8'd4});
           test_packet.set_ipv4_dst_addr({8'd5,8'd6,8'd7,8'd8});
           test_packet.set_mac_src({8'd0,8'd1,8'd2,8'd3,8'd4,8'd5}); // Unused
           test_packet.set_mac_dst({8'd0,8'd6,8'd7,8'd8,8'd9,8'd10}); // Unused
           // Queue packet to UUT
           test_packet.send_udp_to_ipv4_stream(in_axis_pre,1);
           // Add Packet to Golden response FIFO
           if (i !== 7) test_packet.send_udp_to_ipv4_stream(in_axis_golden,1); // Dropped 8th packet from Golden Reference
        end // for (integer i = 0; i < 8; i++)

        // Now send 8 small packets that fit in buffer
        for (integer i = 8; i < 16; i++) begin
           test_packet = UDPPacket::new(1); //1+32 octet packets
           test_packet.set_udp_src_port(i[15:0]+1);
           test_packet.set_udp_dst_port(i[15:0]);
           test_packet.set_ipv4_src_addr({8'd1,8'd2,8'd3,8'd4});
           test_packet.set_ipv4_dst_addr({8'd5,8'd6,8'd7,8'd8});
           test_packet.set_mac_src({8'd0,8'd1,8'd2,8'd3,8'd4,8'd5}); // Unused
           test_packet.set_mac_dst({8'd0,8'd6,8'd7,8'd8,8'd9,8'd10}); // Unused
           // Queue packet to UUT
           test_packet.send_udp_to_ipv4_stream(in_axis_pre,1);
           // Add Packet to Golden response FIFO
           test_packet.send_udp_to_ipv4_stream(in_axis_golden,1); // Dropped 8th packet from Golden Reference
        end // for (integer i = 8; i < 16; i++)
        //
        // Stimulus fully loaded, initialise system for test and release stimulus
        // by opening valve.
        //
        @(negedge clk);
        @(negedge clk);
        // 100% duty cycle on AXIS input bus.
        //enable_stimulus <= 1'b1;
        // Let response threads run
        ready_to_test <= 1;
        //
        `INFO("drop_packet: Stimulus Done");
        //
     end // block: load_stimulus


     // Response thread for output
     begin: read_response_out
        // Close response vavle so data ccumulates in UUT
        enable_response <= 1'b0;
        // Wait until stimulus is loaded.
        while (!ready_to_test) @(posedge clk);
        `INFO("drop_packet: read_response_out running");
        // 100% duty cycle on output buses
        enable_response <= 1'b1;
        // While golden response FIFO not empty
        while (out_axis_golden.tvalid) begin
           // Pop golden response.
           out_axis_golden.read_beat(golden_beat,golden_tlast);
           // Pop response.
           out_axis_post.read_beat(response_beat,response_tlast);
           // Compare response to golden
           `FAIL_UNLESS_EQUAL(golden_beat,response_beat);
           `FAIL_UNLESS_EQUAL(golden_tlast,response_tlast);
        end // while (out0_axis_golden.tvalid)
        // Check CSR status registers hold correct values.
        `FAIL_UNLESS(csr_buffered_packets === 32'd15)
        `FAIL_UNLESS(csr_dropped_packets === 32'd1)
        `INFO("drop_packet: read_response_out finished");
        disable watchdog_thread;
     end // block: read_response_out

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
   in_axis.idle_master();
   out_axis.idle_slave();
endtask // idle_all

endmodule
