//-------------------------------------------------------------------------------
// File:    axis_siggen_unit_test.sv
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
`include "axis_siggen.sv"
`include "../sim_models/fifo_512x72_2clk.v"
`include "../sim_models/fifo_generator_vlog_beh.v"
`include "../sim_models/fifo_generator_v13_2_rfs.v"

module axis_siggen_unit_test;
  timeunit      1fs;
  timeprecision 1fs;
  import svunit_pkg::svunit_testcase;

  string name = "axis_siggen_ut";
  svunit_testcase svunit_ut;

  // --------------------------------------------------------------------------
  // Clocks
  //
  typedef enum {
     CLK__IN = 0
  } clk_enum_t;
  clk_enum_t clk_enum;
  localparam NUM_CLK = clk_enum.num();
  logic clk        [NUM_CLK-1:0];
  time  clk_period [NUM_CLK-1:0];
  logic rst        [NUM_CLK-1:0];
  initial begin
    clk_period[CLK__IN] = $urandom_range(20,1)*1ns; //<-- 50MHz to 1GHz
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
  localparam AXIS_DWIDTH = 32;
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

  assign axis[AXIS__IN].clk = clk[CLK__IN];
  assign axis[AXIS_OUT].clk = clk[CLK__IN];


  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================
  logic        enable;
  logic [31:0] phase_inc;
  logic [ 7:0] waveform;
  logic [15:0] phase_i;
  logic [15:0] phase_q;
  logic [15:0] phase_i_delay;
  logic [15:0] phase_q_delay;
  axis_siggen 
  uut_axis_siggen (
    .clk          (clk [ CLK__IN]),
    .rst          (rst_async     ),

    .enable_in    (enable        ),
    .phase_inc_in (phase_inc     ),
    .waveform_in  (waveform      ),

    .axis_stream_out (axis[AXIS_OUT])
  );

  always_comb begin
    phase_i = axis[AXIS_OUT].tdata[31:16];
    phase_q = axis[AXIS_OUT].tdata[15: 0];
  end

  always_ff @(posedge clk[CLK__IN]) begin
    phase_i_delay <= phase_i;
    phase_q_delay <= phase_q;
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
        repeat(10) @(posedge clk[CLK__IN]);
      end

      begin : frk_setup_in
        repeat(10) @(posedge clk[CLK__IN]);
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
    
    logic [15:0] min_value;
    logic [15:0] max_value;
    realtime     start_time;
    realtime     stop_time;
    realtime     period;
    realtime     predicted_period;
    real         freq;
    real         predicted_freq;

    logic [AXIS_DWIDTH-1:0] axis_payload[$];
    event iter_done;

    logic      tlast;
    logic [63:0] data;

    `INFO("incr_data: send packets with incrementing size");

    idle_all();
    enable    = 1'h1;
    waveform  = 8'h1; //<-- Ramp
    phase_inc = 32'h00FF_0000; //<-- the check_axis_siggen_freq and check_axis_siggen_q_offset functions are currently tuned for this phase_inc. TODO get these functions to work with different values
    axis[AXIS_OUT].tready = 1;

    #50us;

    check_axis_siggen_freq (
      .clk_name     (CLK__IN),
      .enable       (enable),
      .phase_inc    (phase_inc),
      .waveform     (waveform),
      .phase_i      (phase_i),
      .phase_i_delay(phase_i_delay),
      .axis_bus_name(AXIS_OUT),
      .period       (period)
    );

    waveform  = 8'h0; //<-- Square
    #10us;
    check_axis_siggen_freq (
      .clk_name     (CLK__IN),
      .enable       (enable),
      .phase_inc    (phase_inc),
      .waveform     (waveform),
      .phase_i      (phase_i),
      .phase_i_delay(phase_i_delay),
      .axis_bus_name(AXIS_OUT),
      .period       (period)
    );
    
    // 3) Confirm that signal Q is offset by 45-degrees
    waveform = 8'h1; //<-- Ramp
    #10us;
    check_axis_siggen_q_offset (
      .clk_name     (CLK__IN),
      .enable       (enable),
      .phase_inc    (phase_inc),
      .waveform     (waveform),
      .phase_i      (phase_i),
      .phase_i_delay(phase_i_delay),
      .phase_q      (phase_q),
      .phase_q_delay(phase_q_delay),
      .axis_bus_name(AXIS_OUT),
      .period       (period)
    );

    waveform = 8'h0; //<-- Squarewave
    #10us;
    check_axis_siggen_q_offset (
      .clk_name     (CLK__IN),
      .enable       (enable),
      .phase_inc    (phase_inc),
      .waveform     (waveform),
      .phase_i      (phase_i),
      .phase_i_delay(phase_i_delay),
      .phase_q      (phase_q),
      .phase_q_delay(phase_q_delay),
      .axis_bus_name(AXIS_OUT),
      .period       (period)
    );

    //TODO Test AXIS backpressure
    #100us;
    `SVTEST_END

  `SVUNIT_TESTS_END

  task idle_all();
    axis[AXIS__IN].idle_master();
    axis[AXIS_OUT].idle_slave();
  endtask // idle_all

  task automatic check_axis_siggen_freq (
    input  clk_enum_t      clk_name,
    ref    logic           enable,
    ref    logic [31:0]    phase_inc,
    ref    logic [ 7:0]    waveform,
    ref    logic [15:0]    phase_i,
    ref    logic [15:0]    phase_i_delay,
    input  axis_bus_enum_t axis_bus_name,
    output realtime        period
  );
    automatic logic [15:0] min_value;
    automatic logic [15:0] max_value;
    automatic realtime     start_time;
    automatic realtime     stop_time;
    automatic realtime     predicted_period;
    automatic real         freq;
    automatic real         predicted_freq;

    // 1) Find Max and Min values.
    @(phase_i_delay);
    wait(phase_i_delay > phase_i); //<-- Wait for ramp to reset
    min_value = phase_i;
    max_value = phase_i;
    wait(phase_i_delay < phase_i); //<-- Wait for ramp to start climbing

    while(phase_i_delay < phase_i) begin
      if (phase_i > max_value)  begin
        max_value = phase_i;
      end
      if (phase_i < min_value) begin
        min_value = phase_i;
      end
      //$display("min_value: 0x%d; max_value: 0x%d; phase_i: 0x%x; phase_i_delay: 0x%x;", min_value, max_value, phase_i, phase_i_delay);
      @(negedge clk[clk_name]);
    end

    if (waveform === 8'h1) begin //<-- Ramp
      predicted_period = (clk_period[clk_name]/1000)*((max_value-min_value)/(phase_inc[31:16]-1));
      predicted_freq   = 1.0e9/(predicted_period);
    end
    else if (waveform === 8'h0) begin //<- Square Wave
      predicted_period = (clk_period[clk_name]/1000)*((16'h8000*2)/(phase_inc[31:16]));
      predicted_freq   = 1.0e9/(predicted_period);
    end
    
    // 2) Find Period between Max and Min Values
    // This does an unsigned comparison, but the result will be the same.
    axis[AXIS_OUT].tready = 1;
    @(phase_i_delay);
    wait(phase_i_delay < phase_i); //<-- Wait for ramp to start climbing
    wait(phase_i_delay > phase_i); //<-- Wait for ramp to reset
    start_time = $realtime/1000;

    @(phase_i_delay);
    wait(phase_i_delay < phase_i); //<-- Wait for ramp to start climbing
    wait(phase_i_delay > phase_i); //<-- Wait for ramp to reset
    stop_time = $realtime/1000;

    period = (stop_time-start_time);
    freq = 1.0e9/(period);


    $display("waveform: %1d; period: %t; expected period: %t; freq: %dHz; expected freq: %dHz", waveform, period, predicted_period, freq, predicted_freq);
    `FAIL_IF(period !== predicted_period);
    `FAIL_IF(freq   !== predicted_freq  );
  endtask

  task automatic check_axis_siggen_q_offset (
    input  clk_enum_t      clk_name,
    ref    logic           enable,
    ref    logic [31:0]    phase_inc,
    ref    logic [ 7:0]    waveform,
    ref    logic [15:0]    phase_i,
    ref    logic [15:0]    phase_i_delay,
    ref    logic [15:0]    phase_q,
    ref    logic [15:0]    phase_q_delay,
    input  axis_bus_enum_t axis_bus_name,
    output realtime        period
  );
    automatic logic [15:0] min_value;
    automatic logic [15:0] max_value;
    automatic realtime     t0;
    automatic realtime     t1;
    automatic realtime     predicted_q_offset;
    automatic realtime     actual_q_offset;

    // 1) Find Max and Min values.
    @(phase_i_delay);
    wait(phase_i_delay > phase_i); //<-- Wait for ramp to reset
    min_value = phase_i;
    max_value = phase_i;
    wait(phase_i_delay < phase_i); //<-- Wait for ramp to start climbing

    while(phase_i_delay < phase_i) begin
      if (phase_i > max_value)  begin
        max_value = phase_i;
      end
      if (phase_i < min_value) begin
        min_value = phase_i;
      end
      //$display("min_value: 0x%d; max_value: 0x%d; phase_i: 0x%x; phase_i_delay: 0x%x;", min_value, max_value, phase_i, phase_i_delay);
      @(negedge clk[clk_name]);
    end

    if (waveform === 8'h1) begin //<-- Ramp
      predicted_q_offset = (clk_period[clk_name]/1000)*(((max_value-min_value)/4)/(phase_inc[31:16]-4));
    end
    else if (waveform === 8'h0) begin //<-- Square Wave
      predicted_q_offset = (clk_period[clk_name]/1000)*((16'h4000)/(phase_inc[31:16]-4));
    end

    // measure the time between the falling edge of phase_q and the falling edge of phase_i
    // This does an unsigned comparison, but the result will be the same.
    @(phase_q_delay);
    wait(phase_q_delay > phase_q); //<-- Wait for ramp to reset
    t0 = $realtime/1000; //<-- convert fs to ps
    $display("%t capture 1",$time);

    wait(phase_i_delay > phase_i); //<-- Wait for ramp to reset
    t1 = $realtime/1000; //<-- convert fs to ps
    $display("%t capture 2",$time);

    actual_q_offset = t1-t0;

    $display("actual offset: %t; expected offset: %t", actual_q_offset, predicted_q_offset);
    `FAIL_IF(actual_q_offset !== predicted_q_offset);
  endtask

endmodule
