module axis_stream_to_pkt_wrapper #(
        parameter TIME_FIFO_SIZE=4,
        parameter SAMPLE_FIFO_SIZE=13,
        parameter PACKET_FIFO_SIZE=8,
        parameter IQ_WIDTH=16 // Width of IQ samples from Datapath.
    ) (
        input logic                clk,
        input logic                rst,
        // Control signal (Just support free run for now, not time triggered)
        input logic                enable,
        // Populate DRaT Header fields
        input logic [15:3]         packet_size, // Packet size expressed in 64bit words including headers
        input logic [31:0]         flow_id, // DiRT Flow ID for this flow (union of src + dst)
        input logic                flow_id_changed, // Pulse high one cycle when flow_id updated.
        // Status Flags
        output logic               idle,
        output logic               overflow,
        // System Time
        input logic [63:0]         current_time,
        //
        // Streaming IQ Sample bus.
        // Fractional integer data
        // Valid signal to qualify. Not back-pressurable.
        //
        input logic                in_clk,
        input logic [IQ_WIDTH-1:0] in_i,
        input logic [IQ_WIDTH-1:0] in_q,
        input logic                in_valid,
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
        .enable(enable),
        .packet_size(packet_size),
        .flow_id(flow_id),
        .flow_id_changed(flow_id_changed),
        .idle(idle),
        .overflow(overflow),
        .current_time(current_time),
        .in_clk(in_clk),
        .in_i(in_i),
        .in_q(in_q),
        .in_valid(in_valid),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tready(out_tready),
        .out_tlast(out_tlast)
    );
endmodule
