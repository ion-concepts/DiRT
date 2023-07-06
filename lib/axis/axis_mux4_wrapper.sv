module axis_mux4_wrapper #(
        parameter BUFFER=0,  // Add small FIFO on egress.
        parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    ) (
        input logic clk,
        input logic rst,
        axis_t.slave in0_axis,
        axis_t.slave in1_axis,
        axis_t.slave in2_axis,
        axis_t.slave in3_axis,
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
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_mux4 #(
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
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_tready(out_tready)
    );
endmodule
