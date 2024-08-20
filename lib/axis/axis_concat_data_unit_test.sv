//-------------------------------------------------------------------------------
// File:    axis_concat_data_unit_test.sv
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
`include "svunit_defines.svh"
`include "axis_concat_data.sv"
`include "../sim_models/fifo_512x72_2clk.v"
`include "../sim_models/fifo_generator_vlog_beh.v"
`include "../sim_models/fifo_generator_v13_2_rfs.v"

module axis_concat_data_unit_test;
  timeunit      1fs;
  timeprecision 1fs;
  import svunit_pkg::svunit_testcase;

  string name = "axis_concat_data_ut";
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
    $display("clk_period = %t",clk_period[CLK]);
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
    #($urandom_range(10_000,1)*1ns) rst_async = 0;
    #($urandom_range(10_000,1)*1ns) rst_async = 1;
    #($urandom_range(10_000,1)*1ns) rst_async = 0;
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
  localparam CONCAT_WIDTH = 32;
  var logic enable;
  var logic [CONCAT_WIDTH-1:0] concat_data = 32'h1234_5678;

  axis_concat_data #(
    .WIDTH       (CONCAT_WIDTH),
    .AXIS_DWIDTH (AXIS_DWIDTH )
  ) uut_axis_concat_data (
    .clk           (clk[CLK]      ), //input  logic
    .rst           (rst_async     ), //input  logic
    .in_axis       (axis[AXIS__IN]), //axis_t.slave
    .concat_data_in(concat_data   ),
    .out_axis      (axis[AXIS_OUT]), //axis_t.master 
    .enable        (enable        )  //input  logic
  );

  initial begin
    enable = 1;
     //#($urandom_range(10_000,1)*1ns); //<-- randomize the phase. This can help catch bad synchronizers. //TODO randomize duty cycle and freq drift
     //enable = 0;
     //forever begin
     //  #($urandom_range(10_000,1)*1ns) enable = ~enable;
     //end
  end

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
    localparam time timeout  = 5000us;
    localparam int  NUM_PKTS = 10;

    logic [AXIS_DWIDTH-1:0] axis_payload[$] = {};
    logic [AXIS_DWIDTH-1:0] exp_axis_payload[$] = {};
    event iter_done;

    `INFO("incr_data: send packets with incrementing size");

    idle_all();
    #50us;

    for (logic [AXIS_DWIDTH-1:0] i=0; i<NUM_PKTS; i++) begin
      axis_payload.push_back(i);
      exp_axis_payload.push_back({concat_data[CONCAT_WIDTH-1:0], i[AXIS_DWIDTH-CONCAT_WIDTH-1:0]});
      iter_done = null;

      fork
        // Send Packets From DUT -> TB
        begin : in_to_out_host_thread
          @(negedge clk[CLK]);
          send_axis_data_pkt   (.axis_bus_name(AXIS__IN), .axis_payload(axis_payload));
        end
        begin : in_to_out_client_thread
          @(negedge clk[CLK]);
          expect_axis_data_pkt (.axis_bus_name(AXIS_OUT), .exp_axis_payload(exp_axis_payload));
          -> iter_done;
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
      repeat($urandom_range(100,1)) @(posedge clk[i]); //<-- randomize which resets de-assert first
      rst[i] <= 0;
    end
    for (int i = 0; i<NUM_CLK; i++) begin : wait_for_clks
      @(posedge clk[i]);
    end
    #($urandom_range(10_000,1)*1ns) rst_async = 0; 
    #($urandom_range(10_000,1)*1ns) rst_async = 1;
    #($urandom_range(10_000,1)*1ns) rst_async = 0;

    `SVTEST(rand_data)
    localparam time timeout  = 5000us;
    localparam int  NUM_PKTS = 10;
    localparam int  MAX_DATA_BYTES = 10000;
    localparam int  MIN_DATA_BYTES = 1;

    logic [AXIS_DWIDTH-1:0] temp_payload;
    logic [AXIS_DWIDTH-1:0] axis_payload[$];
    logic [AXIS_DWIDTH-1:0] exp_axis_payload[$] = {};
    event                   iter_done;
    int                     rand_case_val;

    `INFO("rand_data: send random packets");

    idle_all();
    #50us;

    for (logic [7:0] i=0; i<100; i++) begin
      iter_done               = null;
      axis_payload            = {};
      exp_axis_payload        = {};

      // Generate random payload
      for (int payload_idx=0; payload_idx<$urandom_range(MAX_DATA_BYTES, MIN_DATA_BYTES); payload_idx++) begin
        temp_payload = {$urandom_range(32'hFFFF_FFFF, 32'h0),$urandom_range(32'hFFFF_FFFF, 32'h0)};
        axis_payload.push_back(temp_payload);
        exp_axis_payload.push_back({concat_data[CONCAT_WIDTH-1:0], temp_payload[AXIS_DWIDTH-CONCAT_WIDTH-1:0]});
      end

      fork
        begin : frk_random_data
          fork
            begin : in_to_out_host_thread
              @(negedge clk[CLK]);
              send_axis_data_pkt  (.axis_bus_name(AXIS__IN), .axis_payload(axis_payload));
            end
            begin : in_to_out_client_thread
              @(negedge clk[CLK]);
              expect_axis_data_pkt(.axis_bus_name(AXIS_OUT), .exp_axis_payload(exp_axis_payload));
              -> iter_done;
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

  task automatic send_axis_data_pkt (
      input      axis_bus_enum_t            axis_bus_name,
      input      logic [AXIS_DWIDTH-1:0]    axis_payload [],
      input      logic                      verbose = 0 
    );
    automatic logic      tlast;
    automatic string     axis_msg = "";
    automatic logic [63:0] data;

    // AXIS payload:
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
      exp_tlast = (beat === exp_axis_payload.size-1);
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
