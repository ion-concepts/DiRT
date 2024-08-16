//-------------------------------------------------------------------------------
// File:    axis_deframer_unit_test.sv
//
// Description:
// Verify that:
// * Any length payload in increments of AXIS_DWIDTH correctly passses through
// * Reset ordering does not matter
// * Works with: (SIZE<=5);             //<-- TODO this does not work
// * Works with: ((SIZE>5)&&(SIZE<=9)); //<-- This works
// * Works occasionally with: (SIZE>9); //<-- TODO This works up to 31, fails above
//
//-------------------------------------------------------------------------------

`include "global_defs.svh"
`include "drat_protocol.sv"
`include "svunit_defines.svh"
`include "axis_deframer.sv"
`include "../sim_models/fifo_512x72_2clk.v"
`include "../sim_models/fifo_generator_vlog_beh.v"
`include "../sim_models/fifo_generator_v13_2_rfs.v"

module axis_deframer_unit_test;
  timeunit      1ps;
  timeprecision 1ps;
  import svunit_pkg::svunit_testcase;
  import drat_protocol::*;

  string name = "axis_deframer_ut";
  svunit_testcase svunit_ut;

  // --------------------------------------------------------------------------
  // Clocks
  //
  typedef enum {
     CLK = 0
  } clk_enum_t;
  clk_enum_t clk_enum;
  localparam NUM_CLK = clk_enum.num();
  logic clk        [NUM_CLK-1:0];
  time  clk_period [NUM_CLK-1:0];
  logic rst        [NUM_CLK-1:0];
  initial begin
    clk_period[CLK] =  $urandom_range(20,1)*1ns; //<-- 50MHz to 1GHz
  end
  generate
    for (genvar i = 0; i<NUM_CLK; i++) begin : gen_clks
      initial begin
        #($urandom_range(1000000000,1)); //<-- randomize the phase. This can help catch bad synchronizers. //TODO randomize duty cycle and freq drift
        clk[i] = 0;
        forever begin
          #(clk_period[i]/2) clk[i] = ~clk[i];
        end
      end
      initial begin : gen_rsts
        @(posedge clk[i]);
        rst[i] <= 0;
        repeat($urandom_range(100,1)) @(posedge clk[i]); //<-- randomize which reset asserts first
        rst[i] <= 1;
        repeat($urandom_range(100,1)) @(posedge clk[i]); //<-- randomize which reset de-asserts first
        rst[i] <= 0;
      end
    end
  endgenerate
  // Create Async Reset
  logic rst_async;
  initial begin
    for (int i = 0; i<NUM_CLK; i++) begin : wait_for_clks
      @(posedge clk[i]);
    end
    #($urandom_range(10_000,1)*1ns) rst_async = 0; //<-- it shouldn't matter which rst[#] this is based on
    #($urandom_range(10_000,1)*1ns) rst_async = 1; //<-- it shouldn't matter which rst[#] this is based on
    #($urandom_range(10_000,1)*1ns) rst_async = 0; //<-- it shouldn't matter which rst[#] this is based on
  end
  

  // --------------------------------------------------------------------------
  // AXIS Busses
  //
  localparam AXIS_DWIDTH = 64;
  localparam NUM_AXIS    = 2;
  typedef enum {
    AXIS__IN = 0, //<-- extra underscore so the print lines up
    AXIS_OUT = 1
  } axis_bus_enum_t;

  axis_t axis [NUM_AXIS-1:0]();
  virtual axis_t axis_vif[NUM_AXIS-1:0];

  generate
    for (genvar i = 0; i < NUM_AXIS; i++) begin : gen_map_phys_to_virtual
      initial axis_vif[i] = axis[i];
    end : gen_map_phys_to_virtual
  endgenerate

  assign axis[AXIS__IN].clk = clk[CLK];
  assign axis[AXIS_OUT].clk = clk[CLK];


  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================
  axis_deframer
  uut_axis_deframer (
     .clk          (clk[CLK]      ), // input logic
     .rst          (rst[CLK]      ), // input logic              
     .enable_in    (1             ), // input logic //<-- TODO test disabled
     .axis_pkt_in  (axis[AXIS__IN]), // axis_t.slave 
     .axis_tail_out(axis[AXIS_OUT])  // axis_t.master
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
    fork

      begin : frk_setup_out
        repeat(10) @(posedge clk[CLK]);
      end

      begin : frk_setup_in
        repeat(10) @(posedge clk[CLK]);
      end

    join
    
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
    `SVTEST(incr_data)
    localparam time timeout  = 500us;
    localparam int  NUM_PKTS = 10;

    logic [AXIS_DWIDTH-1:0]   axis_payload[$];
    event                     iter_done;
    logic [7:0]               drat_seq_id = 0;
    drat_protocol::pkt_type_t drat_packet_type;
    //drat_packet_type = INT16_COMPLEX_ASYNC;
    //drat_packet_type = INT16_COMPLEX_ASYNC_EOB;
    drat_packet_type = INT16_COMPLEX;
    //drat_packet_type = INT16_COMPLEX_EOB;

    `INFO("incr_data: send packets with incrementing size");

    idle_all();
    #50us;

    for (logic [AXIS_DWIDTH-1:0] i=0; i<NUM_PKTS; i++) begin
      axis_payload.push_back(i);
      iter_done = null;

      fork
        // Send Packets From DUT -> TB
        begin : in_to_out_host_thread
          @(posedge clk[CLK]);
          //send_axis_data_pkt   (.axis_bus_name(AXIS__IN), .axis_payload(axis_payload));
          send_drat_data_pkt(
            .axis_bus_name    (AXIS__IN        ),
            .drat_packet_type (drat_packet_type), //<-- TODO try other packet types
            .drat_seq_id      (drat_seq_id     ),
            .drat_flow_src    (16'hABAB        ),
            .drat_flow_dst    (16'hCDCD        ),
            .drat_timestamp   (64'h1234_5678   ),
            .drat_payload     (axis_payload    ),
            .verbose          (1               )
          );
        end
        begin : in_to_out_client_thread
          @(posedge clk[CLK]);
          expect_axis_data_pkt (.axis_bus_name(AXIS_OUT), .exp_axis_payload(axis_payload));
          -> iter_done;
          drat_seq_id++;
        end

        // Wait for all packets received, or timeout
        begin : watchdog
          fork
            begin : watchdog_timeout
              `INFO($sformatf("%m Starting Watchdog"));
              #(timeout);
              `ERROR($sformatf("** Error: %m Watchdog timeout of %t reached", timeout));
              `FAIL_IF(timeout == timeout);
              $stop;
            end
            begin
              wait(iter_done.triggered);
              `INFO($sformatf("%m Ending Watchdog"));
              disable watchdog_timeout;
              `INFO($sformatf("%d/%d Packets Passed!", i, NUM_PKTS));
            end
          join_any
        end

      join
    end //for

    #100us;
    `SVTEST_END

    for (int i = 0; i<NUM_CLK; i++) begin : reset_between_tests
      rst[i] <= 1;
      repeat($urandom_range(100,1)) @(negedge clk[i]); //<-- randomize which resets de-assert first
      rst[i] <= 0;
    end
    for (int i = 0; i<NUM_CLK; i++) begin : wait_for_clks
      @(negedge clk[i]);
    end
    #($urandom_range(10_000,1)*1ns) rst_async = 0; //<-- it shouldn't matter which rst[#] this is based on
    #($urandom_range(10_000,1)*1ns) rst_async = 1; //<-- it shouldn't matter which rst[#] this is based on
    #($urandom_range(10_000,1)*1ns) rst_async = 0; //<-- it shouldn't matter which rst[#] this is based on

    `SVTEST(rand_data)
    localparam time timeout  = 500us;
    localparam int  NUM_PKTS = 10;
    localparam int  MAX_DATA_BYTES = 10000;
    localparam int  MIN_DATA_BYTES = 1;

    logic [AXIS_DWIDTH-1:0]   axis_payload[$];
    event                     iter_done;
    int                       rand_case_val;
    logic [7:0]               drat_seq_id = 0;
    drat_protocol::pkt_type_t drat_packet_type;
    drat_packet_type = INT16_COMPLEX_ASYNC;      //<-- no timestamp (kinda)
    //drat_packet_type = INT16_COMPLEX_ASYNC_EOB;//<-- no timestamp (kinda)
    //drat_packet_type = INT16_COMPLEX;          //<-- has timestamp
    //drat_packet_type = INT16_COMPLEX_EOB;      //<-- has timestamp

    `INFO("rand_data: send random packets");

    idle_all();
    #50us;

    for (logic [7:0] i=0; i<100; i++) begin
      iter_done                = null;
      axis_payload            = {};

      // Generate random payload
      for (int payload_idx=0; payload_idx<$urandom_range(MAX_DATA_BYTES, MIN_DATA_BYTES); payload_idx++) begin
        axis_payload.push_back($urandom_range(8'hFF, 8'h00));
      end

      fork
        begin : frk_random_data
          fork
            begin : in_to_out_host_thread
              @(negedge clk[CLK]);
              // send_axis_data_pkt  (.axis_bus_name(AXIS__IN), .axis_payload(axis_payload));
              // Send the packet using send_drat_data_pkt
              send_drat_data_pkt(
                .axis_bus_name    (AXIS__IN        ),
                .drat_packet_type (drat_packet_type), //<-- TODO try other packet types
                .drat_seq_id      (drat_seq_id     ),
                .drat_flow_src    (16'hABAB        ),
                .drat_flow_dst    (16'hCDCD        ),
                .drat_timestamp   (64'h1234_5678   ),
                .drat_payload     (axis_payload    ),
                .verbose          (1               )
              );
            end
            begin : in_to_out_client_thread
              @(negedge clk[CLK]);
              expect_axis_data_pkt(.axis_bus_name(AXIS_OUT), .exp_axis_payload(axis_payload));
              -> iter_done;
              drat_seq_id++;
            end
          join
        end

        // Wait for packet(s) to be received
        begin : watchdog
          fork
            begin : watchdog_timeout
              `INFO($sformatf("%m Starting Watchdog"));
              #(timeout);
              `ERROR($sformatf("** Error: %m Watchdog timeout of %t reached", timeout));
              `FAIL_IF(timeout == timeout);
              $stop;
            end
            begin
              wait(iter_done.triggered);
              `INFO($sformatf("%m Ending Watchdog"));
              disable watchdog_timeout;
            end
          join_any
        end

      join
    end //for

    #100us;
    `SVTEST_END

  `SVUNIT_TESTS_END

  task idle_all();
    axis[AXIS__IN].idle_master();
    axis[AXIS_OUT].idle_slave();
  endtask // idle_all

  task automatic send_drat_data_pkt (
      input      axis_bus_enum_t            axis_bus_name,
      input      drat_protocol::pkt_type_t  drat_packet_type,
      input      logic [7:0]                drat_seq_id,
      input      logic [15:0]               drat_flow_src,
      input      logic [15:0]               drat_flow_dst,
      input      logic [63:0]               drat_timestamp = 64'hX,
      input      logic [AXIS_DWIDTH-1:0]    drat_payload [],
      input      logic                      verbose = 0 
    );
    automatic logic      tlast;
    automatic logic      packet_has_timestamp = 0;
    automatic string     drat_msg = "";
    automatic logic [63:0] data;
    automatic DRaTPacket drat_packet;

    drat_packet = drat_protocol::DRaTPacket::new();

    // DRaT headers:
    drat_packet.set_seq_id(drat_seq_id);
    drat_packet.set_flow_id({drat_flow_src, drat_flow_dst});
    drat_packet.set_length(drat_protocol::beats_to_bytes(drat_payload.size()+packet_has_timestamp+1)); //<-- +1 for header
    drat_packet.set_packet_type(drat_packet_type);

    if (drat_timestamp !== 64'hX) begin
      packet_has_timestamp = 1;
      drat_packet.set_timestamp(drat_timestamp);
    end

    if (verbose) drat_protocol::print_header(drat_packet.get_header);
    if (verbose) `INFO($sformatf("Sending data on [%s] = %s; raw_header = 0x%h", axis_bus_name, drat_msg, drat_packet.get_raw_header));
    axis_vif[axis_bus_name].write_beat(drat_packet.get_raw_header,1'b0);

    if (packet_has_timestamp === 1) begin
      axis_vif[axis_bus_name].write_beat(drat_packet.get_timestamp,1'b0);
    end

    // DRaT payload:
    foreach (drat_payload[beat]) begin
      tlast = (beat === drat_payload.size-1);
      axis_vif[axis_bus_name].write_beat(drat_payload[beat],tlast);
    end

  endtask

  task automatic expect_drat_data_pkt (
      input      axis_bus_enum_t            axis_bus_name,
      input      drat_protocol::pkt_type_t  drat_packet_type = STRUCTURED,
      input      logic [7:0]                drat_seq_id      = 0,
      input      logic [15:0]               drat_flow_src    = 1234,
      input      logic [15:0]               drat_flow_dst    = 5678,
      input      logic [15:0]               drat_length,
      input      logic [63:0]               drat_timestamp = 64'hX,
      input      logic [AXIS_DWIDTH-1:0]    exp_drat_payload [],
      input      logic                      verbose = 0
    );
    automatic logic                   packet_has_timestamp = 0;
    automatic logic [AXIS_DWIDTH-1:0] rec_axis_data;
    automatic logic                   rec_tlast;
    automatic logic                   exp_tlast;
    automatic string                  axis_data_string = "";

    automatic DRaTPacket exp_drat_packet;

    exp_drat_packet = drat_protocol::DRaTPacket::new();

    if (drat_timestamp !== 64'hX) begin
      packet_has_timestamp = 1;
      exp_drat_packet.set_timestamp(drat_timestamp);
    end

    // DRaT headers:
    exp_drat_packet.set_seq_id(drat_seq_id);
    exp_drat_packet.set_flow_id({drat_flow_src, drat_flow_dst});
    exp_drat_packet.set_length(drat_length);
    exp_drat_packet.set_packet_type(drat_packet_type);

    // rx and comapre DRaT Header:
    exp_tlast = 0;
    axis_vif[axis_bus_name].read_beat(rec_axis_data, rec_tlast);
    $swrite(
      axis_data_string,
      "%s\n  RX[%s] Expected: data = 0x%h, tlast = 0x%h; Actual: data = 0x%h, tlast = 0x%h",
      axis_data_string,
      axis_bus_name,
      exp_drat_packet.get_raw_header,
      exp_tlast    ,
      rec_axis_data,
      rec_tlast    
    );
    if (exp_drat_packet.get_raw_header !== rec_axis_data) begin
      `ERROR($sformatf("Data Mismatch on [%s]: %s <---- ** Error: this line", axis_bus_name, axis_data_string));
      `FAIL_IF(exp_drat_packet.get_raw_header !== rec_axis_data);
      $stop;
    end
    if (exp_tlast !== rec_tlast) begin
      `ERROR($sformatf("tlast Mismatch on [%s]: %s <---- ** Error: this line", axis_bus_name, axis_data_string));
      `FAIL_IF(exp_tlast !== rec_tlast);
      $stop;
    end

    // rx and compare DRaT Payload
    foreach (exp_drat_payload[beat]) begin
      exp_tlast = 0; //<-- line 174 of axis_deframer says tlast is not used for this module. //(beat === exp_drat_payload.size-1);
      axis_vif[axis_bus_name].read_beat(rec_axis_data,rec_tlast);

      $swrite(
        axis_data_string,
        "%s\n  RX[%s] Expected: data = 0x%h, tlast = 0x%h; Actual: data = 0x%h, tlast = 0x%h",
        axis_data_string,
        axis_bus_name,
        exp_drat_payload[beat],
        exp_tlast    ,
        rec_axis_data,
        rec_tlast    
      );

      if (exp_drat_payload[beat] !== rec_axis_data) begin
        `ERROR($sformatf("Data Mismatch on [%s]: %s <---- ** Error: this line", axis_bus_name, axis_data_string));
        `FAIL_IF(exp_drat_payload[beat] !== rec_axis_data);
        $stop;
      end

      if (exp_tlast !== rec_tlast) begin
        `ERROR($sformatf("tlast Mismatch on [%s]: %s <---- ** Error: this line", axis_bus_name, axis_data_string));
        `FAIL_IF(exp_tlast !== rec_tlast);
        $stop;
      end
    end
    `INFO($sformatf("Received Data on [%s]: %s", axis_bus_name, axis_data_string));

  endtask

  task automatic send_axis_data_pkt (
      input      axis_bus_enum_t            axis_bus_name,
      input      logic [AXIS_DWIDTH-1:0]    axis_payload [],
      input      logic                      verbose = 0 
    );
    automatic logic      tlast;
    automatic string     axis_msg = "";
    automatic logic [63:0] data;

    // DRaT payload:
    foreach (axis_payload[beat]) begin
      tlast = (beat === axis_payload.size-1);
      axis_vif[axis_bus_name].write_beat(axis_payload[beat],tlast);
    end

  endtask

  task automatic expect_axis_data_pkt (
      input      axis_bus_enum_t            axis_bus_name,
      input      logic [AXIS_DWIDTH-1:0]    exp_axis_payload [],
      input      logic                      verbose = 0
    );
    automatic logic [AXIS_DWIDTH-1:0] rec_axis_data;
    automatic logic                   rec_tlast;
    automatic logic                   exp_tlast;
    automatic string                  axis_data_string = "";

    // RX and compare AXIS Payload
    foreach (exp_axis_payload[beat]) begin
      exp_tlast = 0; //<-- line 174 of axis_deframer says tlast is not used for this module. //(beat === exp_drat_payload.size-1);
      axis_vif[axis_bus_name].read_beat(rec_axis_data,rec_tlast);

      $swrite(
        axis_data_string,
        "%s\n  RX[%s] Expected: data = 0x%h, tlast = 0x%h; Actual: data = 0x%h, tlast = 0x%h",
        axis_data_string,
        axis_bus_name,
        exp_axis_payload[beat],
        exp_tlast    ,
        rec_axis_data,
        rec_tlast    
      );

      if (exp_axis_payload[beat] !== rec_axis_data) begin
        `ERROR($sformatf("Data Mismatch on [%s]: %s <---- ** Error: this line", axis_bus_name, axis_data_string));
        `FAIL_IF(exp_axis_payload[beat] !== rec_axis_data);
        $stop;
      end

      if (exp_tlast !== rec_tlast) begin
        `ERROR($sformatf("tlast Mismatch on [%s]: %s <---- ** Error: this line", axis_bus_name, axis_data_string));
        `FAIL_IF(exp_tlast !== rec_tlast);
        $stop;
      end
    end
    `INFO($sformatf("Received Data on [%s]: %s", axis_bus_name, axis_data_string));

  endtask

endmodule
