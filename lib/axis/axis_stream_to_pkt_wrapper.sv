module axis_stream_to_pkt_wrapper #(
        parameter TIME_FIFO_SIZE=4,
        parameter SAMPLE_FIFO_SIZE=13,
        parameter PACKET_FIFO_SIZE=8,
        parameter IQ_WIDTH=16 // Width of IQ samples from Datapath.
    ) (
        input logic                clk,
        input logic                rst,
        // Control signal (Just support free run for now, not time triggered)
        input logic                enable_in,
        // Populate DRaT Header fields
        input logic [15:3]         packet_size_in, // Packet size expressed in 64bit words including headers
        input logic [31:0]         flow_id_in, // DiRT Flow ID for this flow (union of src + dst)
        input logic                flow_id_changed_in, // Pulse high one cycle when flow_id updated.
        // Status Flags
        output logic               idle_out,
        output logic               overflow_out,
        // System Time
        input logic [63:0]         current_time_in,
        //
        // Streaming IQ Sample bus.
        // Fractional integer data
        // Valid signal to qualify. Not back-pressurable.
        //
        input logic [IQ_WIDTH-1:0] i_in,
        input logic [IQ_WIDTH-1:0] q_in,
        input logic                valid_in,
        //
        // DiRT Packetized Output AXIS Bus
        //
        axis_t.master out_axis
    );

    logic [63:0] out_tdata;
    logic        out_tvalid;
    logic        out_tready;
    logic        out_tlast;

    always_comb begin
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_tready      = out_axis.tready;
        out_axis.tlast  = out_tlast;
    end

    axis_stream_to_pkt #(
        .TIME_FIFO_SIZE(TIME_FIFO_SIZE),
        .SAMPLE_FIFO_SIZE(SAMPLE_FIFO_SIZE),
        .PACKET_FIFO_SIZE(PACKET_FIFO_SIZE),
        .IQ_WIDTH(IQ_WIDTH)
    ) core (
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .packet_size(packet_size_in),
        .flow_id(flow_id_in),
        .flow_id_changed(flow_id_changed_in),
        .idle(idle_out),
        .overflow(overflow_out),
        .current_time(current_time_in),
        .in_i(i_in),
        .in_q(q_in),
        .in_valid(valid_in),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tready(out_tready),
        .out_tlast(out_tlast)
    );
endmodule
