// Note: this wrapper buffers TLAST, which is different than the core module, which only
// buffers TDATA
module axis_minimal_fifo_wrapper (
        input logic clk,
        input logic rst,
        //
        // Input Bus
        //
        axis_t.slave in_axis,
        //
        // Output Bus
        //
        axis_t.master out_axis,
        //
        // Occupancy
        //
        output logic [1:0] space_out,
        output logic [1:0] occupied_out
    );

    logic [in_axis.WIDTH-1:0]  in_tdata;
    logic                      in_tvalid;
    logic                      in_tlast;
    logic                      in_tready;
    logic [out_axis.WIDTH-1:0] out_tdata;
    logic                      out_tvalid;
    logic                      out_tlast;
    logic                      out_tready;

    always_comb begin
        in_tdata        = in_axis.tdata;
        in_tvalid       = in_axis.tvalid;
        in_tlast        = in_axis.tlast;
        in_axis.tready  = in_tready;
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_minimal_fifo #(.WIDTH(in_axis.WIDTH + 1)) core (
        .clk(clk),
        .rst(rst),
        .in_tdata({in_tlast, in_tdata}),
        .in_tvalid(in_tvalid),
        .in_tready(in_tready),
        .out_tdata({out_tlast, out_tdata}),
        .out_tvalid(out_tvalid),
        .out_tready(out_tready),
        .space(space_out),
        .occupied(occupied_out)
    );
endmodule
