module axis_packet_fifo_wrapper #(
        parameter SIZE=9,        // Size of FIFO (LOG2)
        parameter MAX_PACKETS=8, // Sets number of packets that can be in FIFO concurrently (LOG2)
        parameter VENDOR="XILINX"
    ) (
        input logic clk,
        input logic rst,
        input logic sw_rst,
        //
        // Input Bus
        //
        axis_t.slave in_axis,
        //
        // Output Bus
        //
        axis_t.master out_axis,
        // Occupancy
        output logic [SIZE:0]          space_out,
        output logic [SIZE:0]          occupied_out,
        output logic [MAX_PACKETS-1:0] packet_count_out
    );

    logic [in_axis.WIDTH-1:0]  in_tdata;
    logic                      in_tvalid;
    logic                      in_tready;
    logic                      in_tlast;
    logic [out_axis.WIDTH-1:0] out_tdata;
    logic                      out_tvalid;
    logic                      out_tready;
    logic                      out_tlast;

    always_comb begin
        in_tdata        = in_axis.tdata;
        in_tvalid       = in_axis.tvalid;
        in_axis.tready  = in_tready;
        in_tlast        = in_axis.tlast;
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_tready      = out_axis.tready;
        out_axis.tlast  = out_tlast;
    end

    axis_packet_fifo #(
        .WIDTH(in_axis.WIDTH),
        .SIZE(SIZE),
        .MAX_PACKETS(MAX_PACKETS),
        .VENDOR(VENDOR)
    ) core (
        .clk(clk),
        .rst(rst),
        .sw_rst(sw_rst),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tready(in_tready),
        .in_tlast(in_tlast),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tready(out_tready),
        .out_tlast(out_tlast),
        .space(space_out),
        .occupied(occupied_out),
        .packet_count(packet_count_out)
    );
endmodule
