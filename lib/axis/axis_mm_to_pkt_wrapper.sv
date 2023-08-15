module axis_mm_to_pkt_wrapper #(
        parameter FIFO_SIZE = 10
    ) (
        input logic         clk,
        input logic         rst,
        //-------------------------------------------------------------------------------
        // CSR registers
        //-------------------------------------------------------------------------------
        input logic [31:0]  upper,
        input logic         upper_pls,
        input logic [31:0]  lower_norm,
        input logic         lower_norm_pls,
        input logic [31:0]  lower_last,
        input logic         lower_last_pls,
        output logic [31:0] status,
        //-------------------------------------------------------------------------------
        // AXIS Output Bus
        //-------------------------------------------------------------------------------
        axis_t.master out_axis
    );

    logic [63:0] out_tdata;
    logic        out_tvalid;
    logic        out_tlast;
    logic        out_tready;

    always_comb begin
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_mm_to_pkt #(.FIFO_SIZE(FIFO_SIZE)) core (
        .clk(clk),
        .rst(rst),
        .upper(upper),
        .upper_pls(upper_pls),
        .lower_norm(lower_norm),
        .lower_norm_pls(lower_norm_pls),
        .lower_last(lower_last),
        .lower_last_pls(lower_last_pls),
        .status(status),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_tready(out_tready)
    );

endmodule
