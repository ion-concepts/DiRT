module axis_mux8_wrapper #(
        parameter BUFFER=0,  // Add small FIFO on egress.
        parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    ) (
        input logic clk,
        input logic rst,
        axis_t.slave in0_axis,
        axis_t.slave in1_axis,
        axis_t.slave in2_axis,
        axis_t.slave in3_axis,
        axis_t.slave in4_axis,
        axis_t.slave in5_axis,
        axis_t.slave in6_axis,
        axis_t.slave in7_axis,
        axis_t.master out_axis
    );

    logic [in0_axis.WIDTH-1:0] in0_tdata;
    logic                      in0_tvalid;
    logic                      in0_tlast;
    logic                      in0_tready;
    logic [in1_axis.WIDTH-1:0] in1_tdata;
    logic                      in1_tvalid;
    logic                      in1_tlast;
    logic                      in1_tready;
    logic [in2_axis.WIDTH-1:0] in2_tdata;
    logic                      in2_tvalid;
    logic                      in2_tlast;
    logic                      in2_tready;
    logic [in3_axis.WIDTH-1:0] in3_tdata;
    logic                      in3_tvalid;
    logic                      in3_tlast;
    logic                      in3_tready;
    logic [in4_axis.WIDTH-1:0] in4_tdata;
    logic                      in4_tvalid;
    logic                      in4_tlast;
    logic                      in4_tready;
    logic [in5_axis.WIDTH-1:0] in5_tdata;
    logic                      in5_tvalid;
    logic                      in5_tlast;
    logic                      in5_tready;
    logic [in6_axis.WIDTH-1:0] in6_tdata;
    logic                      in6_tvalid;
    logic                      in6_tlast;
    logic                      in6_tready;
    logic [in7_axis.WIDTH-1:0] in7_tdata;
    logic                      in7_tvalid;
    logic                      in7_tlast;
    logic                      in7_tready;
    logic [out_axis.WIDTH-1:0] out_tdata;
    logic                      out_tvalid;
    logic                      out_tlast;
    logic                      out_tready;

    always_comb begin
        in0_tdata       = in0_axis.tdata;
        in0_tvalid      = in0_axis.tvalid;
        in0_tlast       = in0_axis.tlast;
        in0_axis.tready = in0_tready;
        in1_tdata       = in1_axis.tdata;
        in1_tvalid      = in1_axis.tvalid;
        in1_tlast       = in1_axis.tlast;
        in1_axis.tready = in1_tready;
        in2_tdata       = in2_axis.tdata;
        in2_tvalid      = in2_axis.tvalid;
        in2_tlast       = in2_axis.tlast;
        in2_axis.tready = in2_tready;
        in3_tdata       = in3_axis.tdata;
        in3_tvalid      = in3_axis.tvalid;
        in3_tlast       = in3_axis.tlast;
        in3_axis.tready = in3_tready;
        in4_tdata       = in4_axis.tdata;
        in4_tvalid      = in4_axis.tvalid;
        in4_tlast       = in4_axis.tlast;
        in4_axis.tready = in4_tready;
        in5_tdata       = in5_axis.tdata;
        in5_tvalid      = in5_axis.tvalid;
        in5_tlast       = in5_axis.tlast;
        in5_axis.tready = in5_tready;
        in6_tdata       = in6_axis.tdata;
        in6_tvalid      = in6_axis.tvalid;
        in6_tlast       = in6_axis.tlast;
        in6_axis.tready = in6_tready;
        in7_tdata       = in7_axis.tdata;
        in7_tvalid      = in7_axis.tvalid;
        in7_tlast       = in7_axis.tlast;
        in7_axis.tready = in7_tready;
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_mux8 #(
        .WIDTH(out_axis.WIDTH),
        .BUFFER(BUFFER),
        .PRIORITY(PRIORITY)
    ) core (
        .clk(clk),
        .rst(rst),
        .in0_tdata(in0_tdata),
        .in0_tvalid(in0_tvalid),
        .in0_tlast(in0_tlast),
        .in0_tready(in0_tready),
        .in1_tdata(in1_tdata),
        .in1_tvalid(in1_tvalid),
        .in1_tlast(in1_tlast),
        .in1_tready(in1_tready),
        .in2_tdata(in2_tdata),
        .in2_tvalid(in2_tvalid),
        .in2_tlast(in2_tlast),
        .in2_tready(in2_tready),
        .in3_tdata(in3_tdata),
        .in3_tvalid(in3_tvalid),
        .in3_tlast(in3_tlast),
        .in3_tready(in3_tready),
        .in4_tdata(in4_tdata),
        .in4_tvalid(in4_tvalid),
        .in4_tlast(in4_tlast),
        .in4_tready(in4_tready),
        .in5_tdata(in5_tdata),
        .in5_tvalid(in5_tvalid),
        .in5_tlast(in5_tlast),
        .in5_tready(in5_tready),
        .in6_tdata(in6_tdata),
        .in6_tvalid(in6_tvalid),
        .in6_tlast(in6_tlast),
        .in6_tready(in6_tready),
        .in7_tdata(in7_tdata),
        .in7_tvalid(in7_tvalid),
        .in7_tlast(in7_tlast),
        .in7_tready(in7_tready),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_tready(out_tready)
    );
endmodule
