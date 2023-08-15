module axis_demux4_wrapper #(
        parameter unsigned WIDTH=64  // AXIS datapath width.
    ) (
        input logic              clk,
        input logic              rst,
        //
        // External logic supplies egress port selection.
        //
        output logic [WIDTH-1:0] header_out,
        input logic [1:0]        select_in,

        axis_t.master out0_axis,
        axis_t.master out1_axis,
        axis_t.master out2_axis,
        axis_t.master out3_axis,
        axis_t.slave in_axis
    );

    logic [WIDTH-1:0] out0_tdata;
    logic             out0_tvalid;
    logic             out0_tlast;
    logic             out0_tready;
    logic [WIDTH-1:0] out1_tdata;
    logic             out1_tvalid;
    logic             out1_tlast;
    logic             out1_tready;
    logic [WIDTH-1:0] out2_tdata;
    logic             out2_tvalid;
    logic             out2_tlast;
    logic             out2_tready;
    logic [WIDTH-1:0] out3_tdata;
    logic             out3_tvalid;
    logic             out3_tlast;
    logic             out3_tready;
    logic [WIDTH-1:0] in_tdata;
    logic             in_tvalid;
    logic             in_tlast;
    logic             in_tready;

    always_comb begin
        out0_axis.tdata  = out0_tdata;
        out0_axis.tvalid = out0_tvalid;
        out0_axis.tlast  = out0_tlast;
        out0_tready      = out0_axis.tready;
        out1_axis.tdata  = out1_tdata;
        out1_axis.tvalid = out1_tvalid;
        out1_axis.tlast  = out1_tlast;
        out1_tready      = out1_axis.tready;
        out2_axis.tdata  = out2_tdata;
        out2_axis.tvalid = out2_tvalid;
        out2_axis.tlast  = out2_tlast;
        out2_tready      = out2_axis.tready;
        out3_axis.tdata  = out3_tdata;
        out3_axis.tvalid = out3_tvalid;
        out3_axis.tlast  = out3_tlast;
        out3_tready      = out3_axis.tready;
        in_tdata         = in_axis.tdata;
        in_tvalid        = in_axis.tvalid;
        in_tlast         = in_axis.tlast;
        in_axis.tready   = in_tready;
    end

    axis_demux4 #(.WIDTH(WIDTH)) core (
        .clk(clk),
        .rst(rst),
        .header(header_out),
        .select(select_in),
        .out0_tdata(out0_tdata),
        .out0_tvalid(out0_tvalid),
        .out0_tlast(out0_tlast),
        .out0_tready(out0_tready),
        .out1_tdata(out1_tdata),
        .out1_tvalid(out1_tvalid),
        .out1_tlast(out1_tlast),
        .out1_tready(out1_tready),
        .out2_tdata(out2_tdata),
        .out2_tvalid(out2_tvalid),
        .out2_tlast(out2_tlast),
        .out2_tready(out2_tready),
        .out3_tdata(out3_tdata),
        .out3_tvalid(out3_tvalid),
        .out3_tlast(out3_tlast),
        .out3_tready(out3_tready),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .in_tready(in_tready)
    );

endmodule
